# Braintree for Cordova

This is a [Cordova](http://cordova.apache.org/) plugin for the [Braintree](https://www.braintreepayments.com/) mobile payment processing SDK. It extends the [Cordova Purchase Plugin](https://github.com/j3k0/cordova-plugin-purchase/) to add Braintree support using the Braintree DropIn interface.

## Installing

The plugin identifier is `cordova-plugin-purchase-braintree`. Here's how to adding it to your app with the cordova CLI:

```sh
cordova plugin add cordova-plugin-purchase-braintree`
```

**For Android**, you have to make sure the `minSdkVersion` is at least `21` in your app's `config.xml` file. To do so, add (or update) the `preference` tag for the `android` platform as below:

```xml
<platform name="android">
    <preference name="android-minSdkVersion" value="21" />
</platform>
```

**For iOS**, the minimum deployment target for the Braintree SDK is iOS 12.0, to set this up, add (or update) the `preference` tag for the `ios` platform like so:

```xml
<platform name="ios">
    <preference name="deployment-target" value="12.0" />
</platform>
```

## Usage

### Initialization

When initializing the purchase plugin, add `Platform.BRAINTREE` at initialization.

```ts
CdvPurchase.store.initialize([{
    platform: CdvPurchase.Platform.BRAINTREE,
    options: { ... }
}]);
```

The options object should contain a `clientTokenProvider` or a `tokenizationKey` string. Check the [Braintree documentation](https://developer.paypal.com/braintree/docs/start/overview) to understand the difference.

`clientTokenProvider` is a function that takes a callback as a parameter, this callback will accept either:

- a string: the `Client Token`
- a `CdvPurchase.IError` object (`{code: ErrorNumber, message: string}`).

The CdvPurchase.Iaptic object contains the implementation of a client token provider. So you can do:

```ts
const iaptic = new CdvPurchase.Iaptic({
  url: 'https://validator.iaptic.com', appName: 'MY_APP_NAME', apiKey: 'MY_PUBLIC_KEY',
});
store.initialize([Platform.APPLE_APPSTORE, Platform.GOOGLE_PLAY, {
    platform: Platform.BRAINTREE,
    options: {
        clientTokenProvider: iaptic.braintreeClientTokenProvider // iaptic's braintree client token provider
    }
}]);
```

### Making a purchase

Use the `store.requestPayment()` method to initiate a payment with Braintree.

- `amountMicros` and `currency` are required.
- If `result.isError` is set, the returned value is an error.
  - Check `result.code`, `PAYMENT_CANCELLED` means the user closed the modal window.
  - Other error codes means something went wrong.

```ts
store.requestPayment({
  platform: CdvPurchase.Platform.BRAINTREE,
  productIds: ['my-product-1', 'my-product-2'], // Use anything, for reference
  amountMicros: 1990000,
  currency: 'USD',
  description: 'This this the description of the payment request',
}).then((result) => {
  if (result && result.isError && result.code !== CdvPurchase.ErrorCode.PAYMENT_CANCELLED) {
    alert(result.message);
  }
});
```

Once the client gets the initial approval, the `"approved"` event is triggered. It's the job of
the receipt validation service to create and submit a transaction to Braintree.

Once again, iaptic has built-in support for Braintree, so this part is already covered if your
app is integrated with Iaptic. If now, implement the server side call using values provided by
the receipt validation call.
