# Braintree for Cordova

This is a [Cordova](http://cordova.apache.org/) plugin for the [Braintree](https://www.braintreepayments.com/) mobile payment processing SDK. It extends the [Cordova Purchase Plugin](https://github.com/j3k0/cordova-plugin-purchase/) to add Braintree support using the Braintree DropIn interface.

This plugin requires at least cordova-plugin-purchase version 13.

## Installing

The plugin identifier is `cordova-plugin-purchase-braintree`. Here's how to adding it to your app with the cordova CLI:

```sh
cordova plugin add cordova-plugin-purchase-braintree
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

The options object should contain:
- a `clientTokenProvider` or a `tokenizationKey` string.
- optional configuration options for Apple Pay, Google Pay and 3DSecure.

#### Client Token or Tokenization Key

Check the [Braintree documentation](https://developer.paypal.com/braintree/docs/guides/authorization/overview) to understand the difference.

`clientTokenProvider` is a function that takes a callback as a parameter, this callback will accept either:

- a `string`: the Client Token
- a `CdvPurchase.IError` object (`{isError: true, code: ErrorNumber, message: string}`).

The CdvPurchase.Iaptic object contains the implementation of a client token provider. So you if you are using https://www.iaptic.com, you can do:

```ts
const iaptic = new CdvPurchase.Iaptic({
  url: 'https://validator.iaptic.com', appName: 'MY_APP_NAME', apiKey: 'MY_PUBLIC_KEY',
});

store.initialize([Platform.APPLE_APPSTORE, Platform.GOOGLE_PLAY, {
    platform: Platform.BRAINTREE,
    options: {
        // using iaptic's built-in braintree client token provider
        clientTokenProvider: iaptic.braintreeClientTokenProvider
    }
}]);
```

`tokenizationKey` is just a string.

### Making a purchase

Use the `store.requestPayment()` method to initiate a payment with Braintree.

- `amountMicros` and `currency` are required.
- If `result.isError` is set, the returned value is an error.
  - Check `result.code`, `PAYMENT_CANCELLED` means the user closed the modal window.
  - Other error codes means something went wrong.

```ts
store.requestPayment({
  platform: CdvPurchase.Platform.BRAINTREE,
  email: GetEmailAddress(),
  items: [{
    id: 'item_id',
    title: 'An Item',
    pricing: { // 11 USD
        priceMicros: 11 * 1000000,
        currency: 'USD',
    }
  }],
  description: 'An item delivered before Christmas',
})
.cancelled(() => {
  // request cancelled by user
})
.failed(error => {
  // request failed
})
.initiated(transaction => {
  // transaction initiated
})
.approved(transaction => {
  // transaction initiated
})
.finished(transaction => {
  // transaction finished
});
```

Once the client gets the initial approval, the `"approved"` event is triggered. It's the job of
the receipt validation service to create and submit a transaction to Braintree.

Once again, iaptic has built-in support for Braintree, so this part is already covered if your
app is integrated with Iaptic. If now, implement the server side call using values provided by
the receipt validation call.

### 3DSecure

To enable 3DSecure, you have to add `threeDSecure` into the platform options.

Example:
```js
{
  platform: Platform.BRAINTREE,
  options: {
    // ...
    threeDSecure: {
      exemptionRequested: true
    }
  }
}
```

It can also be an empty object if you don't have any specific options to set. The list of accepted options is documented here: [ThreeDSecure.Request](https://github.com/j3k0/cordova-plugin-purchase/blob/master/api/interfaces/CdvPurchase.Braintree.ThreeDSecure.Request.md).

Those options will be merged into all Braintree payment requests. They can be overloaded by adding `threeDSecureRequest` in the payment request' additional data, for example:

```js
CdvPurchase.store.requestPayment({
    platform: CdvPurchase.Platform.BRAINTREE,
    items: [/* */],
    email: GetEmailAddress(),
}, {
  braintree: {
    threeDSecureRequest: {
      exemptionRequested: false
    }
  }
});
```

`threeDSecureRequest` is of the same type: a [ThreeDSecure.Request](https://github.com/j3k0/cordova-plugin-purchase/blob/master/api/interfaces/CdvPurchase.Braintree.ThreeDSecure.Request.md) object.

### Google Pay

To enable Google Pay, you have to add `googlePay` into the platform options.

Example:
```js
{
  platform: Platform.BRAINTREE,
  options: {
    // ...
    googlePay: {
      countryCode: 'US',
      googleMerchantName: 'My Merchant Name',
      environment: 'TEST'
    },
  }
}
```

The list of accepted options is documented here: [GooglePay.Request](https://github.com/j3k0/cordova-plugin-purchase/blob/master/api/interfaces/CdvPurchase.Braintree.GooglePay.Request.md).

Those options will be merged into all Braintree payment requests. As with 3DSecure, those options can be overloaded by adding `googlePayRequest` into the payment request's additional data, for example.

```js
CdvPurchase.store.requestPayment({
    platform: CdvPurchase.Platform.BRAINTREE,
    items: [/* */],
}, {
  braintree: {
    googlePayRequest: {
      shippingAddressRequired: true,
    },
  }
});
```

### Apple Pay

The [cordova-plugin-purchase-braintree-applepay](https://github.com/j3k0/cordova-plugin-purchase-braintree-applepay) plugin is an extension that enables support for Apple. By installing this plugin, you can add support for Apple Pay to your Cordova app, through Braintree.

Documentation related to Apple Pay can be found in that repository.

## Licence

The MIT License

Copyright (c) 2022, Jean-Christophe Hoelt and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
