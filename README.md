# Braintree for Cordova

This is a [Cordova](http://cordova.apache.org/) plugin for the [Braintree](https://www.braintreepayments.com/) mobile payment processing SDK. It extends the [Cordova Purchase Plugin](https://github.com/j3k0/cordova-plugin-purchase/) to add Braintree support.

## Installing

The plugin identifier is `cordova-plugin-purchase-braintree`. Here's how to adding it to your app with the cordova CLI:

```sh
cordova plugin add cordova-plugin-purchase-braintree`
```

For Android, you have to make sure the `minSdkVersion` is at least `21` in your app's `config.xml` file.

Add (or update) the `preference` tag for the `android` platform as below:

```xml
<platform name="android">
    <preference name="android-minSdkVersion" value="21" />
</platform>
```

## Usage

When initializing the purchase plugin, add `Platform.BRAINTREE` at initialization.

```ts
CdvPurchase.store.initialize([CdvPurchase.Platform.BRAINTREE]);
```
