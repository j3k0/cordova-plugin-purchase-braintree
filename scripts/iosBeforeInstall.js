const fs = require('fs');
const https = require('https');
const { execSync } = require('child_process');

const IOS_FRAMEWORKS_PATH = 'plugins/cordova-plugin-purchase-braintree/lib/ios';
const TEMP_PATH = 'plugins/cordova-plugin-purchase-braintree/tmp';

const BRAINTREE_IOS_VERSION = '5.15.0';
const BRAINTREE_IOS_RELEASE_URL = `https://github.com/braintree/braintree_ios/releases/download/${BRAINTREE_IOS_VERSION}/Braintree.xcframework.zip`;

// To be executed before installing a plugin (to the platforms).
module.exports = async function (context) {

    if (fs.existsSync(IOS_FRAMEWORKS_PATH + '/BraintreeCore.xcframework/Info.plist')) {
        // frameworks already installed.
        return;
    }

    if (!fs.existsSync(TEMP_PATH)) {
        // 0- Create temporary directory
        fs.mkdirSync(TEMP_PATH, { recursive: true });
    }

    // 1- Download the XCFramework release from github
    if (!fs.existsSync(`${TEMP_PATH}/Braintree.xcframework`)) {
        console.log("Downloading Braintree SDK version " + BRAINTREE_IOS_VERSION + ", from " + BRAINTREE_IOS_RELEASE_URL);
        await download(BRAINTREE_IOS_RELEASE_URL, `${TEMP_PATH}/Braintree.xcframework.zip`);
    }

    // 2- Create "fraweworks" directory
    if (!fs.existsSync(IOS_FRAMEWORKS_PATH)) {
        fs.mkdirSync(IOS_FRAMEWORKS_PATH, { recursive: true });
    }

    // 3- Extract 
    console.log("Extracting Braintree SDK...");
    execSync(`unzip -o "${TEMP_PATH}/Braintree.xcframework.zip" -d "${TEMP_PATH}"`);
    execSync(`rsync -a "${TEMP_PATH}/Carthage/Build/" "${IOS_FRAMEWORKS_PATH}"`);

    // 4- Cleanup
    execSync(`rm -fr "${TEMP_PATH}"`);
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