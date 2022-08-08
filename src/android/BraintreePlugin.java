package net.justincredible;

import android.util.Log;
import android.app.Activity;
import android.content.Intent;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.braintreepayments.api.BraintreeFragment;
import com.braintreepayments.api.DataCollector;
import com.braintreepayments.api.PayPal;
import com.braintreepayments.api.dropin.DropInActivity;
import com.braintreepayments.api.dropin.DropInRequest;
import com.braintreepayments.api.dropin.DropInResult;
import com.braintreepayments.api.interfaces.PaymentMethodNonceCreatedListener;
import com.braintreepayments.api.interfaces.BraintreeErrorListener;
import com.braintreepayments.api.models.CardNonce;
import com.braintreepayments.api.models.GooglePaymentRequest;
import com.braintreepayments.api.models.PayPalAccountNonce;
import com.braintreepayments.api.models.PayPalRequest;
import com.braintreepayments.api.models.PaymentMethodNonce;
import com.braintreepayments.api.models.ThreeDSecureInfo;
import com.braintreepayments.api.models.ThreeDSecureRequest;
import com.braintreepayments.api.models.VenmoAccountNonce;
import com.google.android.gms.wallet.TransactionInfo;
import com.google.android.gms.wallet.WalletConstants;
import java.util.HashMap;
import java.util.Map;

import io.sentry.util.Nullable;

public final class BraintreePlugin extends CordovaPlugin implements PaymentMethodNonceCreatedListener, BraintreeErrorListener {

    private static final String TAG = "BraintreePlugin";

    private static final int DROP_IN_REQUEST = 100;
    private static final int PAYMENT_BUTTON_REQUEST = 200;
    private static final int CUSTOM_REQUEST = 300;
    private static final int PAYPAL_REQUEST = 400;

    private PayPalRequest payPalRequest = null;
    private DropInRequest dropInRequest = null;
    private CallbackContext _callbackContext = null;
    private BraintreeFragment braintreeFragment = null;
    private String temporaryToken = null;

    @Override
    public synchronized boolean execute(String action, final JSONArray args, final CallbackContext callbackContext) throws JSONException {

        if (action == null) {
            Log.e(TAG, "execute ==> exiting for bad action");
            return false;
        }

        Log.w(TAG, "execute ==> " + action + " === " + args);

        _callbackContext = callbackContext;

        try {
            if (action.equals("initialize")) {
                this.initializeBT(args);
            } else if (action.equals("presentDropInPaymentUI")) {
                this.presentDropInPaymentUI(args);
            } else if (action.equals("paypalProcess")) {
                this.paypalProcess(args);
            } else if (action.equals("paypalProcessVaulted")) {
                this.paypalProcessVaulted();
            } else if (action.equals("setupApplePay")) {
                this.setupApplePay();
            } else {
                return false;
            }
        } catch (Exception exception) {
            callbackContext.error("BraintreePlugin uncaught exception: " + exception.getMessage());
        }

        return true;
    }

    @Override
    public void onError(Exception error) {
        Log.e(TAG, "Caught error from BraintreeSDK: " + error.getMessage());
        _callbackContext.error("BraintreePlugin uncaught exception: " + error.getMessage());
    }
    
    private synchronized void initializeBT(final JSONArray args) throws Exception {

        if (args.length() != 1) {
            _callbackContext.error("A token is required.");
            return;
        }

        String token = args.getString(0);

        if (token == null || token.equals("")) {
            _callbackContext.error("A token is required.");
            return;
        }

        temporaryToken = token;
        _callbackContext.success();
    }

    private synchronized void setupApplePay() throws JSONException {
        // Apple Pay available on iOS only
        _callbackContext.success();
    }

    /**
     *
     * @param dropInRequest
     * @param amount
     * @param currency
     * @param merchantId
     */
    private void enableGooglePay(DropInRequest dropInRequest, String amount, String currency, @Nullable String merchantId) {
        GooglePaymentRequest googlePaymentRequest = new GooglePaymentRequest()
                .transactionInfo(TransactionInfo.newBuilder()
                        .setTotalPrice(amount)
                        .setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL)
                        .setCurrencyCode(currency)
                        .build())
                        .billingAddressRequired(true);

        if (merchantId != null && merchantId.length() > 0) {
            googlePaymentRequest.googleMerchantId(merchantId);
        }


        dropInRequest.googlePaymentRequest(googlePaymentRequest);
    }

    private synchronized void presentDropInPaymentUI(final JSONArray args) throws JSONException {

        // Ensure the client has been initialized.
        if (temporaryToken == null) {
            _callbackContext.error("The Braintree client must first be initialized via BraintreePlugin.initialize(token)");
            return;
        }

        String btToken = temporaryToken;
        temporaryToken = null;

        dropInRequest = new DropInRequest().clientToken(btToken);

        if (dropInRequest == null) {
            _callbackContext.error("The Braintree client failed to initialize.");
            return;
        }

        // Ensure we have the correct number of arguments.
        if (args.length() < 1) {
            _callbackContext.error("amount is required.");
            return;
        }
        try {
            // Obtain the arguments.

            String amount = args.getString(0);

            if (amount == null) {
                _callbackContext.error("amount is required.");
            }

            String primaryDescription = args.getString(1);

            JSONObject threeDSecure = args.getJSONObject(2);
            JSONObject googlePay = args.getJSONObject(3);

            if (threeDSecure == null) {
                _callbackContext.error("threeDSecure is required.");
            }

            dropInRequest.amount(amount);
            ThreeDSecureRequest threeDSecureRequest = new ThreeDSecureRequest();
            threeDSecureRequest.amount(threeDSecure.getString("amount"));
            threeDSecureRequest.email(threeDSecure.getString("email"));
            threeDSecureRequest.versionRequested(ThreeDSecureRequest.VERSION_2);
            dropInRequest.requestThreeDSecureVerification(true);
            dropInRequest.collectDeviceData(true);
            dropInRequest.vaultManager(true);
            dropInRequest.threeDSecureRequest(threeDSecureRequest);

            if (googlePay != null) {
                enableGooglePay(dropInRequest, amount, googlePay.getString("currency"), googlePay.getString("merchantId"));
            }



            Intent intent = dropInRequest.getIntent(this.cordova.getActivity());

            if (intent == null) {
                Log.e(TAG, "presentDropInPaymentUI failed ===> unable to create Braintree DropInRequest");
                _callbackContext.error(TAG + ": presentDropInPaymentUI failed ===> unable to create Braintree DropInRequest");
                return;
            }

            this.cordova.startActivityForResult(this, intent, DROP_IN_REQUEST);
        } catch (Exception e) {
            Log.e(TAG, "presentDropInPaymentUI failed with error ===> " + e.getMessage());
            _callbackContext.error(TAG + ": presentDropInPaymentUI failed with error ===> " + e.getMessage());
        }
    }

    private synchronized void paypalProcess(final JSONArray args) throws Exception {
        payPalRequest = new PayPalRequest(args.getString(0));
        payPalRequest.currencyCode(args.getString(1));
        PayPal.requestOneTimePayment(braintreeFragment, payPalRequest);
    }

    private synchronized void paypalProcessVaulted() throws Exception {
        PayPal.requestBillingAgreement(braintreeFragment, payPalRequest);
    }

    // Results

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        super.onActivityResult(requestCode, resultCode, intent);

        Log.i(TAG, "DropIn Activity Result: " + requestCode + ", " + resultCode);

        if (_callbackContext == null) {
            Log.e(TAG, "onActivityResult exiting ==> callbackContext is invalid");
            return;
        }

        if (requestCode == DROP_IN_REQUEST) {

            PaymentMethodNonce paymentMethodNonce = null;

            if (resultCode == Activity.RESULT_OK) {
                if (intent != null) {
                    DropInResult result = intent.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
                    paymentMethodNonce = result.getPaymentMethodNonce();
                }

                Log.i(TAG, "DropIn Activity Result: paymentMethodNonce = " + paymentMethodNonce);
            }

            // handle errors here, an exception may be available in
            if (intent != null && intent.getSerializableExtra(DropInActivity.EXTRA_ERROR) != null) {
                Exception error = (Exception) intent.getSerializableExtra(DropInActivity.EXTRA_ERROR);
                Log.e(TAG, "onActivityResult exiting ==> received error: " + error.getMessage() + "\n" + error.getStackTrace());
                _callbackContext.error("onActivityResult exiting ==> received error: " + error.getMessage());
                return;
            }
            if (intent != null) {
                DropInResult result = intent.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
                String deviceData = result.getDeviceData();
                this.handleDropInPaymentUiResult(resultCode, paymentMethodNonce, deviceData);
                return;
            }
            _callbackContext.error("Activity result handler for CUSTOM_REQUEST failed.");
            return;
        } else if (requestCode == PAYMENT_BUTTON_REQUEST) {
            //TODO
            _callbackContext.error("Activity result handler for PAYMENT_BUTTON_REQUEST not implemented.");
        } else if (requestCode == CUSTOM_REQUEST) {
            _callbackContext.error("Activity result handler for CUSTOM_REQUEST not implemented.");
            //TODO
        } else if (requestCode == PAYPAL_REQUEST) {
            _callbackContext.error("Activity result handler for PAYPAL_REQUEST not implemented.");
            //TODO
        } else {
            Log.w(TAG, "onActivityResult exiting ==> requestCode [" + requestCode + "] was unhandled");
        }
    }

    /**
     * Helper used to handle the result of the drop-in payment UI.
     *
     * @param resultCode         Indicates the result of the UI.
     * @param paymentMethodNonce Contains information about a successful payment.
     */
    private void handleDropInPaymentUiResult(int resultCode, PaymentMethodNonce paymentMethodNonce, String deviceData) {

        Log.i(TAG, "handleDropInPaymentUiResult resultCode ==> " + resultCode + ", paymentMethodNonce = " + paymentMethodNonce);

        if (_callbackContext == null) {
            Log.e(TAG, "handleDropInPaymentUiResult exiting ==> callbackContext is invalid");
            return;
        }

        if (resultCode == Activity.RESULT_CANCELED) {
            Map<String, Object> resultMap = new HashMap<String, Object>();
            resultMap.put("userCancelled", true);
            _callbackContext.success(new JSONObject(resultMap));
            _callbackContext = null;
            return;
        }

        if (paymentMethodNonce == null) {
            _callbackContext.error("Result was not RESULT_CANCELED, but no PaymentMethodNonce was returned from the Braintree SDK (was " + resultCode + ").");
            _callbackContext = null;
            return;
        }

        Map<String, Object> resultMap = this.getPaymentUINonceResult(paymentMethodNonce, deviceData);
        _callbackContext.success(new JSONObject(resultMap));
        _callbackContext = null;
    }

    /**
     * Helper used to return a dictionary of values from the given payment method nonce.
     * Handles several different types of nonces (eg for cards, PayPal, etc).
     *
     * @param paymentMethodNonce The nonce used to build a dictionary of data from.
     * @return The dictionary of data populated via the given payment method nonce.
     */
    private Map<String, Object> getPaymentUINonceResult(PaymentMethodNonce paymentMethodNonce, String deviceData) {

        Map<String, Object> resultMap = new HashMap<String, Object>();

        resultMap.put("nonce", paymentMethodNonce.getNonce());
        resultMap.put("deviceData", deviceData);
        resultMap.put("type", paymentMethodNonce.getTypeLabel());
        resultMap.put("localizedDescription", paymentMethodNonce.getDescription());

        // Card
        if (paymentMethodNonce instanceof CardNonce) {
            CardNonce cardNonce = (CardNonce) paymentMethodNonce;

            Map<String, Object> innerMap = new HashMap<String, Object>();
            innerMap.put("lastTwo", cardNonce.getLastTwo());
            innerMap.put("network", cardNonce.getCardType());

            resultMap.put("card", innerMap);
        }

        // PayPal
        if (paymentMethodNonce instanceof PayPalAccountNonce) {
            PayPalAccountNonce payPalAccountNonce = (PayPalAccountNonce) paymentMethodNonce;

            Map<String, Object> innerMap = new HashMap<String, Object>();
            resultMap.put("email", payPalAccountNonce.getEmail());
            resultMap.put("firstName", payPalAccountNonce.getFirstName());
            resultMap.put("lastName", payPalAccountNonce.getLastName());
            resultMap.put("phone", payPalAccountNonce.getPhone());
            resultMap.put("clientMetadataId", payPalAccountNonce.getClientMetadataId());
            resultMap.put("payerId", payPalAccountNonce.getPayerId());

            resultMap.put("paypalAccount", innerMap);
        }

        // 3D Secure
        if (paymentMethodNonce instanceof CardNonce) {
            CardNonce cardNonce = (CardNonce) paymentMethodNonce;
            ThreeDSecureInfo threeDSecureInfo = cardNonce.getThreeDSecureInfo();

            if (threeDSecureInfo != null) {
                Map<String, Object> innerMap = new HashMap<String, Object>();
                innerMap.put("liabilityShifted", threeDSecureInfo.isLiabilityShifted());
                innerMap.put("liabilityShiftPossible", threeDSecureInfo.isLiabilityShiftPossible());

                resultMap.put("threeDSecureInfo", innerMap);
            }
        }

        // Venmo
        if (paymentMethodNonce instanceof VenmoAccountNonce) {
            VenmoAccountNonce venmoAccountNonce = (VenmoAccountNonce) paymentMethodNonce;

            Map<String, Object> innerMap = new HashMap<String, Object>();
            innerMap.put("username", venmoAccountNonce.getUsername());

            resultMap.put("venmoAccount", innerMap);
        }

        return resultMap;
    }

    @Override
    public void onPaymentMethodNonceCreated(PaymentMethodNonce paymentMethodNonce) {
        Log.i(TAG, "onPaymentMethodNonceCreated  ==> paymentMethodNonce = " + paymentMethodNonce);

        if (_callbackContext == null) {
            Log.e(TAG, "onPaymentMethodNonceCreated exiting ==> callbackContext is invalid");
            return;
        }

        try {
            JSONObject json = new JSONObject();

            json.put("nonce", paymentMethodNonce.getNonce().toString());
//            json.put("deviceData", DataCollector.collectDeviceData(braintreeFragment));
            // json.put("deviceData", DataCollector.collectDeviceData(braintreeFragment, this));

            if (paymentMethodNonce instanceof PayPalAccountNonce) {
                PayPalAccountNonce pp = (PayPalAccountNonce) paymentMethodNonce;
                json.put("payerId", pp.getPayerId().toString());
                json.put("firstName", pp.getFirstName().toString());
                json.put("lastName", pp.getLastName().toString());
            }

            _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, json));
        } catch (Exception e) {
            Log.e(TAG, "onPaymentMethodNonceCreated  ==> error:" + e.getMessage());
            e.printStackTrace();
        }
    }
}
