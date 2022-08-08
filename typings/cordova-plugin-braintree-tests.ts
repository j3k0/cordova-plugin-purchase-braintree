/// <reference path="cordova-plugin-braintree-3ds.d.ts" />

BraintreePlugin.initialize("a");
BraintreePlugin.initialize("a", () => {});
BraintreePlugin.initialize("a", () => {}, () => {});

var paymentUIOptions: BraintreePlugin.PaymentUIOptions = {
    amount: "49.99",
    primaryDescription: "Your Item"
};

BraintreePlugin.presentDropInPaymentUI();
BraintreePlugin.presentDropInPaymentUI(paymentUIOptions);
BraintreePlugin.presentDropInPaymentUI(paymentUIOptions, (result: BraintreePlugin.PaymentUIResult) => {});
BraintreePlugin.presentDropInPaymentUI(paymentUIOptions, (result: BraintreePlugin.PaymentUIResult) => {}, () => {});

var applePayOptions: BraintreePlugin.ApplePayOptions = {
    merchantId: "com.braintree.merchant.demoapp",
    currency: "USD",
    country: "US"
};
BraintreePlugin.setupApplePay(applePayOptions);
BraintreePlugin.setupApplePay(applePayOptions, () => {});
BraintreePlugin.setupApplePay(applePayOptions, () => {}, () => {});
