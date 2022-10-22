/**
 * There's a problem with CocoaPods when using custom build directories.
 * 
 * https://github.com/CocoaPods/CocoaPods/issues/10675
 * 
 * So this issue causes a problem with Cordova, in particular for the Braintree SDK:
 * https://github.com/braintree/braintree_ios/issues/880
 * https://github.com/apache/cordova-ios/issues/617 
 * 
 * I'm trying to create a fix for CocoaPods.
 * https://github.com/CocoaPods/CocoaPods/commit/26f5842f4035ae6d422cdce89e82bd3be1ecc756
 * 
 * Until this is finalized, the below should patch the Xcode project so the app builds with `cordova build ios`.
 */
const fs = require('fs');
const PATCH_MARKER = 'PATCHED BY cordova-plugin-purchase-braintree';

/**
 * Patches the Pods project's resource script.
 * 
 * Because it doesn't work when using custom build directories.
 */
function patchPodsResourcesScript(path) {
    const data = fs.readFileSync(path, 'utf-8');
    const lines = data.split(/\r?\n/);
    const outputLines = [];
    let patched = false;
    const regex = /[ ]*install_resource \"\${PODS_CONFIGURATION_BUILD_DIR}\/BraintreeDropIn\/BraintreeDropIn-Localization.bundle\"$/
    lines.forEach(line => {
        if (regex.test(line)) {
            patched = true;
            outputLines.push(`if [ -e "\${BUILT_PRODUCTS_DIR}/BraintreeDropIn-Localization.bundle" ]; then                               # ${PATCH_MARKER}`);
            outputLines.push(`  install_resource "\${BUILT_PRODUCTS_DIR}/BraintreeDropIn-Localization.bundle"                            # ${PATCH_MARKER}`);
            outputLines.push(`elif [ -e "\${PODS_CONFIGURATION_BUILD_DIR}/BraintreeDropIn/BraintreeDropIn-Localization.bundle" ]; then   # ${PATCH_MARKER}`);
            outputLines.push(`  install_resource "\${PODS_CONFIGURATION_BUILD_DIR}/BraintreeDropIn/BraintreeDropIn-Localization.bundle"  # ${PATCH_MARKER}`);
            outputLines.push(`else                                                                                                      # ${PATCH_MARKER}`);
            outputLines.push(`  echo Failed to install BraintreeDropIn-Localization.bundle >&2                                          # ${PATCH_MARKER}`);
            outputLines.push(`  exit 1                                                                                                  # ${PATCH_MARKER}`);
            outputLines.push(`fi                                                                                                        # ${PATCH_MARKER}`);
        }
        else {
            outputLines.push(line);
        }
    });
    if (patched) {
        console.log(`File ${path} patched by cordova-plugin-purchase-braintree`);
        fs.writeFileSync(path + '.orig', lines.join('\n'), 'utf-8');
        fs.writeFileSync(path, outputLines.join('\n'), 'utf-8');
    }
}

function patchPodsPbxproj(path) {
    const data = fs.readFileSync(path, 'utf-8');
    const lines = data.split(/\r?\n/);
    const outputLines = [];
    let patched = false;
    const regexBeginSection = /^\/\*[ ]*Begin PBXShellScriptBuildPhase section[ ]*\*\//
    const regexEndSection = /^\/\*[ ]*End PBXShellScriptBuildPhase section[ ]*\*\//

    let inSection = false;

    lines.forEach(line => {

        if (regexBeginSection.test(line)) {
            inSection = true;
        }
        else if (regexEndSection.test(line)) {
            inSection = false;
        }

        if (inSection) {
          // Update output paths
          if (/^\t\t\t\t\${BUILT_PRODUCTS_DIR}\/\${PRODUCT_MODULE_NAME}\.modulemap,$/.test(line)) {
            line = '\t\t\t\t${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/${PRODUCT_MODULE_NAME}.modulemap,';
            patched = true;
          }
          else if (/^\t\t\t\t\${BUILT_PRODUCTS_DIR}\/Braintree-umbrella\.h,$/.test(line)) {
            line = '\t\t\t\t${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/#{relative_umbrella_header_path.basename},';
            patched = true;
          }
          else if (/^\t\t\t\t\${BUILT_PRODUCTS_DIR}\/Swift\\ Compatibility\\ Header\/\${PRODUCT_MODULE_NAME}-Swift\.h,$/.test(line)) {
            line = '\t\t\t\t${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/Swift\\ Compatibility\\ Header/${PRODUCT_MODULE_NAME}-Swift.h,';
            patched = true;
          }
          else if (/^\t\t\tshellScript\s*=\s*(".*[^\\]");$/.test(line)) {
            // The shell script that needs to be patched
            const shellScript = /^\t\t\tshellScript = (\".*\");$/.exec(line)[1];
            /** @type string */
            const parsedShellScript = JSON.parse(shellScript);
            const shellScriptLines = parsedShellScript.split('\n');
            if (shellScriptLines.length >= 6 && /^COMPATIBILITY_HEADER_PATH=/.test(shellScriptLines[0]) && /^MODULE_MAP_PATH=/.test(shellScriptLines[1])) {
              // It looks like this is our problematic CocoaPods script, let's patch it.
              // We replace BUILT_PRODUCTS_DIR with PODS_CONFIGURATION_BUILD_DIR/PRODUCT_MODULE_NAME
              const outputLines = shellScriptLines.map(ssLine => ssLine.replace(/BUILT_PRODUCTS_DIR/g, 'PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME'));
              const outputShellScript = JSON.stringify(outputLines.join('\n'));
              if (outputShellScript !== parsedShellScript) {
                patched = true;
                line = '\t\t\tshellScript = ' + outputShellScript + ';';
              }
            }
          }
        }

        outputLines.push(line);
    });
    if (patched) {
        console.log(`File ${path} patched by cordova-plugin-purchase-braintree`);
        fs.writeFileSync(path + '.orig', lines.join('\n'), 'utf-8');
        fs.writeFileSync(path, outputLines.join('\n'), 'utf-8');
    }
}

module.exports = async function(context) {

    // example, importing a cordova module.
    const cordovaCommon = context.requireCordovaModule('cordova-common');
    const appConfig = new cordovaCommon.ConfigParser('config.xml');
    const appName = appConfig.name();

    // We want to patch the Xcode project.

    // 1. in platforms/ios/Pods/Target Support files/Pods-$PROJECT_NAME/Pods-$PROJECT_NAME-resources.sh
    //    update calls to:
    //        install_resource "${PODS_CONFIGURATION_BUILD_DIR}/BraintreeDropIn/BraintreeDropIn-Localization.bundle"    
    //    modified like this:
    //        if [ -e "${BUILT_PRODUCTS_DIR}/BraintreeDropIn-Localization.bundle" ]; then
    //          install_resource "${BUILT_PRODUCTS_DIR}/BraintreeDropIn-Localization.bundle"
    //        elif [ -e "${PODS_CONFIGURATION_BUILD_DIR}/BraintreeDropIn/BraintreeDropIn-Localization.bundle" ]; then
    //          install_resource "${PODS_CONFIGURATION_BUILD_DIR}/BraintreeDropIn/BraintreeDropIn-Localization.bundle"
    //        else
    //          echo Failed to install BraintreeDropIn-Localization.bundle >&2
    //          exit 1
    //        fi
    patchPodsResourcesScript(`platforms/ios/Pods/Target Support files/Pods-${appName}/Pods-${appName}-resources.sh`);

    // 2. in "platforms/ios/Pods/Pods.xcodeproj/project.pbxproj"
    //    (cf https://github.com/CocoaPods/CocoaPods/compare/master...j3k0:CocoaPods:j3k0-patch-10675?expand=1)
    //
    // Shell script:
    // - COMPATIBILITY_HEADER_PATH="${BUILT_PRODUCTS_DIR}/Swift Compatibility Header/${PRODUCT_MODULE_NAME}-Swift.h"
    // - MODULE_MAP_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.modulemap"
    // + COMPATIBILITY_HEADER_PATH="${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/Swift Compatibility Header/${PRODUCT_MODULE_NAME}-Swift.h"
    // + MODULE_MAP_PATH="${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/${PRODUCT_MODULE_NAME}.modulemap"
    // ditto "${DERIVED_SOURCES_DIR}/${PRODUCT_MODULE_NAME}-Swift.h" "${COMPATIBILITY_HEADER_PATH}"
    // ditto "${PODS_ROOT}/#{relative_module_map_path}" "${MODULE_MAP_PATH}"
    // - ditto "${PODS_ROOT}/#{relative_umbrella_header_path}" "${BUILT_PRODUCTS_DIR}"
    // + ditto "${PODS_ROOT}/#{relative_umbrella_header_path}" "${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}"
    // printf "\\n\\nmodule ${PRODUCT_MODULE_NAME}.Swift {\\n  header \\"${COMPATIBILITY_HEADER_PATH}\\"\\n  requires objc\\n}\\n" >> "${MODULE_MAP_PATH}"
    //
    // Output paths:
    // - ${BUILT_PRODUCTS_DIR}/${PRODUCT_MODULE_NAME}.modulemap
    // - ${BUILT_PRODUCTS_DIR}/#{relative_umbrella_header_path.basename}
    // - ${BUILT_PRODUCTS_DIR}/Swift\ Compatibility\ Header/${PRODUCT_MODULE_NAME}-Swift.h
    // + ${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/${PRODUCT_MODULE_NAME}.modulemap
    // + ${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/#{relative_umbrella_header_path.basename}
    // + ${PODS_CONFIGURATION_BUILD_DIR}/${PRODUCT_MODULE_NAME}/Swift\ Compatibility\ Header/${PRODUCT_MODULE_NAME}-Swift.h
    patchPodsPbxproj("platforms/ios/Pods/Pods.xcodeproj/project.pbxproj");
}