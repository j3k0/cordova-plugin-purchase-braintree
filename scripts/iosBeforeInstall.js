const fs = require('fs');
const https = require('https');
const { execSync, exec } = require('child_process');

const IOS_FRAMEWORKS_PATH = 'plugins/cordova-plugin-purchase-braintree/lib/ios';
const TEMP_PATH = '.downloads/cordova-plugin-purchase-braintree';

const BRAINTREE_IOS_VERSION = '5.23.0';
const BRAINTREE_IOS_RELEASE_URL = `https://github.com/braintree/braintree_ios/releases/download/${BRAINTREE_IOS_VERSION}/Braintree.xcframework.zip`;
const BRAINTREE_IOS_REPO_ARCHIVE_URL = `https://github.com/braintree/braintree_ios/archive/refs/tags/${BRAINTREE_IOS_VERSION}.zip`;

const PAYPALCHECKOUT_IOS_VERSION = '0.110.0';
const PAYPALCHECKOUT_IOS_RELEASE_URL = `https://github.com/paypal/paypalcheckout-ios/releases/download/${PAYPALCHECKOUT_IOS_VERSION}/PayPalCheckout.xcframework.zip`;

const CARDINAL_MOBILE_VERSION = '2.2.5-3';
// https://assets.braintreegateway.com/mobile/ios/carthage-frameworks/cardinal-mobile/CardinalMobile.json"
const CARDINAL_MOBILE_URL = `https://assets.braintreegateway.com/mobile/ios/carthage-frameworks/cardinal-mobile/CardinalMobile.${CARDINAL_MOBILE_VERSION}.xcframework.zip`;

// To be executed before installing a plugin (to the platforms).
module.exports = async function (context) {

    // clean up old download directory
    if (!fs.existsSync(`${TEMP_PATH}/${BRAINTREE_IOS_VERSION}`)) {
        execSync(`rm -fr "${TEMP_PATH}"`);
    }

    if (fs.existsSync(IOS_FRAMEWORKS_PATH + '/BraintreeCore.xcframework/Info.plist')
        && fs.existsSync(IOS_FRAMEWORKS_PATH + '/CardinalMobile.xcframework/Info.plist')) {
        // frameworks already installed.
        return;
    }

    if (!fs.existsSync(TEMP_PATH)) {
        // 0- Create temporary directory
        fs.mkdirSync(TEMP_PATH, { recursive: true });
        execSync(`echo "Temporary files for cordova-plugin-purchase-braintree" >"${TEMP_PATH}/README"`);
    }

    // 1a- Download the XCFramework release from github
    if (!fs.existsSync(`${TEMP_PATH}/Braintree.xcframework.zip`)) {
        console.log("Downloading Braintree SDK version " + BRAINTREE_IOS_VERSION + ", from " + BRAINTREE_IOS_RELEASE_URL);
        await download(BRAINTREE_IOS_RELEASE_URL, `${TEMP_PATH}/Braintree.xcframework.zip`);
    }

    // 1b- Download PayPalCheckout
    if (!fs.existsSync(`${TEMP_PATH}/PayPalCheckout.xcframework.zip`)) {
        console.log("Downloading PayPalCheckout SDK version " + PAYPALCHECKOUT_IOS_VERSION + ", from " + PAYPALCHECKOUT_IOS_RELEASE_URL);
        await download(PAYPALCHECKOUT_IOS_RELEASE_URL, `${TEMP_PATH}/PayPalCheckout.xcframework.zip`);
    }

    // 1c- Download braintree_ios repository (it contains additional frameworks that are required)
    if (!fs.existsSync(`${TEMP_PATH}/Braintree-Repo.zip`)) {
        console.log("Downloading Braintree repository version " + BRAINTREE_IOS_VERSION + ", from " + BRAINTREE_IOS_REPO_ARCHIVE_URL);
        await download(BRAINTREE_IOS_REPO_ARCHIVE_URL, `${TEMP_PATH}/Braintree-Repo.zip`);
    }

    // 2- Create "frameworks" directory
    if (!fs.existsSync(IOS_FRAMEWORKS_PATH)) {
        fs.mkdirSync(IOS_FRAMEWORKS_PATH, { recursive: true });
    }

    execSync(`touch "${TEMP_PATH}/${BRAINTREE_IOS_VERSION}"`);

    // 3- Extract 
    console.log("Extracting Braintree SDK...");
    execSync(`unzip -o "${TEMP_PATH}/Braintree.xcframework.zip" -d "${TEMP_PATH}"`);
    execSync(`unzip -o "${TEMP_PATH}/Braintree-Repo.zip" -d "${TEMP_PATH}"`);
    execSync(`rsync -a "${TEMP_PATH}/Carthage/Build/" "${IOS_FRAMEWORKS_PATH}"`);

    console.log("Adding PayPalCheckout SDK as a top-level dependency...");
    // fixing "Invalid Bundle. The bundle at '/Frameworks/BraintreePayPalNativeCheckout.framework' contains disallowed nested bundles."
    // PayPalCheckout is removed as a nested framework, now installed as a top-level dependency
    execSync(`unzip -o "${TEMP_PATH}/PayPalCheckout.xcframework.zip" -d "${TEMP_PATH}"`);
    execSync(`rsync -a --delete "${TEMP_PATH}/PayPalCheckout.xcframework" "${IOS_FRAMEWORKS_PATH}/"`);
    execSync(`rm -fr "${TEMP_PATH}/PayPalCheckout.xcframework"`);
    execSync(`rm -fr "${IOS_FRAMEWORKS_PATH}/BraintreePayPalNativeCheckout.xcframework/ios-arm64/BraintreePayPalNativeCheckout.framework/Frameworks"`);
    execSync(`rm -fr "${IOS_FRAMEWORKS_PATH}/BraintreePayPalNativeCheckout.xcframework/ios-arm64_x86_64-simulator/BraintreePayPalNativeCheckout.framework/Frameworks"`);
    // execSync(`rsync -a "${TEMP_PATH}/CardinalMobile.${CARDINAL_MOBILE_VERSION}.xcframework/" "${IOS_FRAMEWORKS_PATH}/CardinalMobile.xcframework"`);
    execSync(`rsync -a --delete "${TEMP_PATH}/braintree_ios-${BRAINTREE_IOS_VERSION}/Frameworks/XCFrameworks/PPRiskMagnes.xcframework" "${IOS_FRAMEWORKS_PATH}/"`);
    execSync(`rsync -a --delete "${TEMP_PATH}/braintree_ios-${BRAINTREE_IOS_VERSION}/Frameworks/XCFrameworks/CardinalMobile.xcframework" "${IOS_FRAMEWORKS_PATH}/"`);
    execSync(`rsync -a --delete "${TEMP_PATH}/braintree_ios-${BRAINTREE_IOS_VERSION}/Frameworks/XCFrameworks/KountDataCollector.xcframework" "${IOS_FRAMEWORKS_PATH}/"`);

    // 4- Cleanup
    // execSync(`rm -fr "${TEMP_PATH}"`);
}

/**
 * Download a resource from `url` to `dest`.
 * @param {string} url - Valid URL to attempt download of resource
 * @param {string} dest - Valid path to save the file.
 * @returns {Promise<void>} - Returns asynchronously when successfully completed download
 */
function download(url, dest) {
    return new Promise((resolve, reject) => {
        // Check file does not exist yet before hitting network
        fs.access(dest, fs.constants.F_OK, (err) => {

            if (err === null) reject('File already exists');

            const request = https.get(url, response => {
                if (response.statusCode === 200) {

                    const file = fs.createWriteStream(dest, { flags: 'wx' });
                    file.on('finish', () => resolve());
                    file.on('error', err => {
                        file.close();
                        if (err.code === 'EEXIST') reject('File already exists');
                        else fs.unlink(dest, () => reject(err.message)); // Delete temp file
                    });
                    response.pipe(file);
                } else if (response.statusCode === 302 || response.statusCode === 301) {
                    //Recursively follow redirects, only a 200 will resolve.
                    download(response.headers.location, dest).then(() => resolve());
                } else {
                    reject(`Server responded with ${response.statusCode}: ${response.statusMessage}`);
                }
            });

            request.on('error', err => {
                reject(err.message);
            });
        });
    });
}
