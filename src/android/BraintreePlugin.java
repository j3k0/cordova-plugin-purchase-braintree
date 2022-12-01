package cc.fovea;

// import android.app.Activity;
// import android.content.Intent;
import android.util.Log;
// import com.braintreepayments.api.BraintreeFragment;
// import com.braintreepayments.api.DataCollector;
// import com.braintreepayments.api.PayPal;
// import com.braintreepayments.api.dropin.DropInActivity;
// import com.braintreepayments.api.BraintreeClient;
import com.braintreepayments.api.UserCanceledException;
import com.braintreepayments.api.AuthorizationException;
import com.braintreepayments.api.DropInClient;
import com.braintreepayments.api.DropInRequest;
import com.braintreepayments.api.DropInListener;
import com.braintreepayments.api.DropInResult;
import com.braintreepayments.api.DropInPaymentMethod;
// import com.braintreepayments.api.interfaces.BraintreeErrorListener;
// import com.braintreepayments.api.models.CardNonce;
// import com.braintreepayments.api.models.GooglePaymentRequest;
// import com.braintreepayments.api.models.PayPalAccountNonce;
// import com.braintreepayments.api.models.PayPalRequest;
// import com.braintreepayments.api.models.PaymentMethodNonce;
// import com.braintreepayments.api.models.ThreeDSecureInfo;
import com.braintreepayments.api.ThreeDSecureRequest;
import com.braintreepayments.api.ThreeDSecureAdditionalInformation;
import com.braintreepayments.api.ThreeDSecurePostalAddress;

// import javax.swing.event.TreeSelectionEvent;

// import com.braintreepayments.api.models.VenmoAccountNonce;
// import com.google.android.gms.wallet.TransactionInfo;
// import com.google.android.gms.wallet.WalletConstants;
// import java.util.HashMap;
// import java.util.Map;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Entrypoint for the Android Braintree Plugin.
 */
public final class BraintreePlugin extends CordovaPlugin
    implements DropInListener {
  // BraintreeErrorListener,
  // PaymentMethodNonceCreatedListener,

  /**
   * TAG used for logs.
   */
  public static final String TAG = "CordovaPurchase.Braintree";

  // private static final int DROP_IN_REQUEST = 100;
  // private static final int PAYMENT_BUTTON_REQUEST = 200;
  // private static final int CUSTOM_REQUEST = 300;
  // private static final int PAYPAL_REQUEST = 400;

  /**
   * DropIn client.
   *
   * See https://developer.paypal.com/braintree/docs/start/hello-client
   */
  private DropInClient dropInClient;

  /**
   * Cordova callback context used to send asynchronous messages to JS.
   */
  private CallbackContext listenerContext;

  /**
   * Cordova callback context used to respond to a DropIn request.
   */
  private CallbackContext dropInCallbackContext;;

  // private PayPalRequest payPalRequest = null;
  // private DropInRequest dropInRequest = null;

  // private BraintreeFragment braintreeFragment = null;

  /*
   * Client for the Braintree SDK.
   */
  // private BraintreeClient braintreeClient;

  /** Provides Braintree SDK with Client Tokens when it needs them. */
  private BraintreeTokenProvider clientTokenProvider =
      new BraintreeTokenProvider(this);

  // private String tokenizationKey = null;

  /** Method receiving calls from javascript. */
  @Override
  public boolean execute(
      String action,
      JSONArray args,
      CallbackContext callbackContext) throws JSONException {

    BraintreePlugin that = this;
    if (action == null) {
      Log.e(TAG, "Execute: No action provided");
      return false;
    }
    try {
      Log.i(TAG, "execute(" + action + ")");
      if ("setListener".equals(action)) {
        that.listenerContext = callbackContext;
        sendToListener("ready", new JSONObject());
      } else if ("launchDropIn".equals(action)) {
        that.launchDropIn(callbackContext, args);
      } else if ("onClientTokenSuccess".equals(action)) {
        that.onClientTokenSuccess(callbackContext, args);
      } else if ("onClientTokenFailure".equals(action)) {
        that.onClientTokenFailure(callbackContext, args);
      } else {
        return false;
      }
    } catch (Exception exception) {
      exception.printStackTrace();
      callbackContext.error("BraintreePlugin uncaught exception: "
          + exception.getMessage());
    }

    return true;
  }

  /**
   * Called when app is first made visible to the user.
   */
  @Override
  public void onStart() {
    if (this.dropInClient == null) {
      this.createDropInClient(null);
    }
  }

  /**
   * Called when app is created and plugin loaded.
   */
  @Override
  public void pluginInitialize() {
    Log.d(TAG, "pluginInitialize from "
        + Thread.currentThread().getName() + " thread");
    if (Thread.currentThread().getName().equals("main")) {
      if (this.dropInClient == null) {
        this.createDropInClient(null);
      }
    }
  }

  /**
   * Creates the DropInClient as soon as the app starts.
   *
   * In principle this will get called from `pluginInitialize`
   * which is run by the Activity's `onCreate`, because we are
   * setting "onload=true" in the plugin.xml file.
   *
   * This is a requirement for the Braintree Android implementation
   * because it uses internally some activity state listener that
   * needs to be initialize before the `onStart` event.
   *
   * We're also checking if it runs in the main thread, as it is 
   * another requirement for the SDK initialization.
   */
  private void createDropInClientAtStartup() {
    try {
      Log.i(TAG, "Initializing Braintree.DropInClient...");
      DropInClient lDropInClient = new DropInClient(
          this.cordova.getActivity(),
          this.clientTokenProvider);
      // this.clientTokenProvider);
      lDropInClient.setListener(this);
      this.dropInClient = lDropInClient;
      Log.i(TAG, "Braintree.DropInClient Initialized");
    } catch (Exception e) {
      Log.d(TAG, "Failed to initialize Braintree.DropInClient");
      e.printStackTrace();
    }
  }

  /**
   * @param callbackContext The callback context to call when dropInClient is
   *                        ready, or null if none.
   */
  private void createDropInClient(final CallbackContext callbackContext) {
    BraintreePlugin that = this;
    if (that.dropInClient == null) {
      that.createDropInClientAtStartup();
    }
    if (callbackContext != null) {
      callbackContext.success();
    }
  }

  /**
   * Called when the ClientTokenProvider responded.
   *
   * @param callbackContext Cordova's callback.
   * @param args            Arguments passed to the native call.
   */
  private synchronized void onClientTokenSuccess(
      final CallbackContext callbackContext,
      final JSONArray args)
      throws Exception {
    Log.d(TAG, "onClientTokenSuccess");
    if (this.clientTokenProvider == null) {
      callbackContext.success();
      return;
    }
    if (args.length() != 1) {
      callbackContext.error("Incorrect number of arguments.");
      return;
    }
    String clientToken = args.getString(0);
    this.clientTokenProvider.onClientTokenSuccess(clientToken);
    callbackContext.success();
  }

  /**
   * Called when the ClientTokenProvider responded.
   *
   * @param callbackContext Cordova's callback.
   * @param args            Arguments passed to the native call.
   */
  private synchronized void onClientTokenFailure(
      final CallbackContext callbackContext,
      final JSONArray args)
      throws Exception {
    if (this.clientTokenProvider == null) {
      callbackContext.success();
      return;
    }
    if (args.length() != 2) {
      callbackContext.error("Incorrect number of arguments.");
      return;
    }
    String errorMessage = args.getString(1);
    this.clientTokenProvider.onClientTokenFailure(errorMessage);
    callbackContext.success();
  }

  private String parseVersionRequested(
      final JSONObject obj,
      final String field) {
    try {
      if (!obj.has(field)) {
        return ThreeDSecureRequest.VERSION_2;
      }
      if (obj.getInt(field) == 0) {
        return ThreeDSecureRequest.VERSION_1;
      }
      return ThreeDSecureRequest.VERSION_2;
    } catch (Exception e) {
      return ThreeDSecureRequest.VERSION_2;
    }
  }

  private Boolean parseBoolean(
      final JSONObject obj,
      final String field,
      final Boolean defaultValue) {
    try {
      if (!obj.has(field)) {
        return defaultValue;
      }
      return obj.getBoolean(field);
    } catch (Exception e) {
      return defaultValue;
    }
  }

  private int parseInt(
      final JSONObject obj,
      final String field,
      final int defaultValue) {
    try {
      if (!obj.has(field)) {
        return defaultValue;
      }
      return obj.getInt(field);
    } catch (Exception e) {
      return defaultValue;
    }
  }

  /**
   * Additional information for a 3DS lookup. Used in 3DS 2.0+ flows.
   *
   * @return ThreeDSecureAdditionalInformation object or null.
   */
  private ThreeDSecureAdditionalInformation parse3DSAdditionalInformation(
      final JSONObject obj,
      final String field) throws JSONException {

    if (!obj.has(field)) {
      return null;
    }
    JSONObject input = obj.getJSONObject(field);
    ThreeDSecureAdditionalInformation ret = new ThreeDSecureAdditionalInformation();

    if (input.has("shippingAddress")) {
      ret.setShippingAddress(
          parse3DSPostalAddress(input, "shippingAddress"));
    }
    if (input.has("shippingMethodIndicator")) {
      ret.setShippingMethodIndicator(
          input.getString("shippingMethodIndicator"));
    }
    if (input.has("productCode")) {
      ret.setProductCode(input.getString("productCode"));
    }
    if (input.has("deliveryTimeframe")) {
      ret.setDeliveryTimeframe(input.getString("deliveryTimeframe"));
    }
    if (input.has("deliveryEmail")) {
      ret.setDeliveryEmail(input.getString("deliveryEmail"));
    }
    if (input.has("reorderIndicator")) {
      ret.setReorderIndicator(input.getString("reorderIndicator"));
    }
    if (input.has("preorderIndicator")) {
      ret.setPreorderIndicator(input.getString("preorderIndicator"));
    }
    if (input.has("preorderDate")) {
      ret.setPreorderDate(input.getString("preorderDate"));
    }
    if (input.has("giftCardAmount")) {
      ret.setGiftCardAmount(input.getString("giftCardAmount"));
    }
    if (input.has("giftCardCurrencyCode")) {
      ret.setGiftCardCurrencyCode(input.getString("giftCardCurrencyCode"));
    }
    if (input.has("giftCardCount")) {
      ret.setGiftCardCount(input.getString("giftCardCount"));
    }
    if (input.has("accountAgeIndicator")) {
      ret.setAccountAgeIndicator(input.getString("accountAgeIndicator"));
    }
    if (input.has("accountCreateDate")) {
      ret.setAccountCreateDate(
          input.getString("accountCreateDate"));
    }
    if (input.has("accountChangeIndicator")) {
      ret.setAccountChangeIndicator(
          input.getString("accountChangeIndicator"));
    }
    if (input.has("accountChangeDate")) {
      ret.setAccountChangeDate(input.getString("accountChangeDate"));
    }
    if (input.has("accountPwdChangeIndicator")) {
      ret.setAccountPwdChangeIndicator(
          input.getString("accountPwdChangeIndicator"));
    }
    if (input.has("accountPwdChangeDate")) {
      ret.setAccountPwdChangeDate(
          input.getString("accountPwdChangeDate"));
    }
    if (input.has("shippingAddressUsageIndicator")) {
      ret.setShippingAddressUsageIndicator(
          input.getString("shippingAddressUsageIndicator"));
    }
    if (input.has("shippingAddressUsageDate")) {
      ret.setShippingAddressUsageDate(
          input.getString("shippingAddressUsageDate"));
    }
    if (input.has("transactionCountDay")) {
      ret.setTransactionCountDay(
          input.getString("transactionCountDay"));
    }
    if (input.has("transactionCountYear")) {
      ret.setTransactionCountYear(
          input.getString("transactionCountYear"));
    }
    if (input.has("addCardAttempts")) {
      ret.setAddCardAttempts(
          input.getString("addCardAttempts"));
    }
    if (input.has("accountPurchases")) {
      ret.setAccountPurchases(
          input.getString("accountPurchases"));
    }
    if (input.has("fraudActivity")) {
      ret.setFraudActivity(
          input.getString("fraudActivity"));
    }
    if (input.has("shippingNameIndicator")) {
      ret.setShippingNameIndicator(
          input.getString("shippingNameIndicator"));
    }
    if (input.has("paymentAccountIndicator")) {
      ret.setPaymentAccountIndicator(
          input.getString("paymentAccountIndicator"));
    }
    if (input.has("paymentAccountAge")) {
      ret.setPaymentAccountAge(
          input.getString("paymentAccountAge"));
    }
    if (input.has("addressMatch")) {
      ret.setAddressMatch(
          input.getString("addressMatch"));
    }
    if (input.has("accountID")) {
      ret.setAccountId(input.getString("accountID"));
    }
    if (input.has("ipAddress")) {
      ret.setIpAddress(input.getString("ipAddress"));
    }
    if (input.has("orderDescription")) {
      ret.setOrderDescription(
          input.getString("orderDescription"));
    }
    if (input.has("taxAmount")) {
      ret.setTaxAmount(
          input.getString("taxAmount"));
    }
    if (input.has("userAgent")) {
      ret.setUserAgent(input.getString("userAgent"));
    }
    if (input.has("authenticationIndicator")) {
      ret.setAuthenticationIndicator(
          input.getString("authenticationIndicator"));
    }
    if (input.has("installment")) {
      ret.setInstallment(input.getString("installment"));
    }
    if (input.has("purchaseDate")) {
      ret.setPurchaseDate(input.getString("purchaseDate"));
    }
    if (input.has("recurringEnd")) {
      ret.setRecurringEnd(input.getString("recurringEnd"));
    }
    if (input.has("recurringFrequency")) {
      ret.setRecurringFrequency(input.getString("recurringFrequency"));
    }
    if (input.has("sdkMaxTimeout")) {
      ret.setSdkMaxTimeout(input.getString("sdkMaxTimeout"));
    }
    if (input.has("workPhoneNumber")) {
      ret.setWorkPhoneNumber(input.getString("workPhoneNumber"));
    }
    return ret;
  }

  private ThreeDSecurePostalAddress parse3DSPostalAddress(
      final JSONObject obj,
      final String field) {

    try {

      // @link
      // https://braintree.github.io/braintree_ios/current/Classes/BTThreeDSecurePostalAddress.html
      if (!obj.has(field)) {
        return null;
      }
      JSONObject input = obj.getJSONObject(field);
      ThreeDSecurePostalAddress ret = new ThreeDSecurePostalAddress();
      if (input.has("givenName")) {
        ret.setGivenName(input.getString("givenName"));
      }
      if (input.has("surname")) {
        ret.setSurname(input.getString("surname"));
      }
      if (input.has("streetAddress")) {
        ret.setStreetAddress(input.getString("streetAddress"));
      }
      if (input.has("extendedAddress")) {
        ret.setExtendedAddress(input.getString("extendedAddress"));
      }
      if (input.has("line3")) {
        ret.setLine3(input.getString("line3"));
      }
      if (input.has("locality")) {
        ret.setLocality(input.getString("locality"));
      }
      if (input.has("region")) {
        ret.setRegion(input.getString("region"));
      }
      if (input.has("postalCode")) {
        ret.setPostalCode(input.getString("postalCode"));
      }
      if (input.has("phoneNumber")) {
        ret.setPhoneNumber(input.getString("phoneNumber"));
      }
      if (input.has("countryCodeAlpha2")) {
        ret.setCountryCodeAlpha2(input.getString("countryCodeAlpha2"));
      }

      return ret;
    } catch (Exception e) {
      e.printStackTrace();
      return null;
    }
  }

  private ThreeDSecureRequest parseThreeDSecureRequest(final JSONObject obj, final String field) throws JSONException {

    if (!obj.has(field))
      return null;
    JSONObject input = obj.getJSONObject(field);

    ThreeDSecureRequest req = new ThreeDSecureRequest();
    Log.d(TAG, "ThreeDSecureRequest: amount=" + input.getString("amount"));
    Log.d(TAG, "                     nonce=" + input.getString("nonce"));
    req.setAmount(input.getString("amount"));
    req.setNonce(input.getString("nonce"));
    if (input.has("email")) {
      req.setEmail(input.getString("email"));
    }
    if (input.has("versionRequested")) {
      req.setVersionRequested(this.parseVersionRequested(input, "versionRequested"));
    }
    if (input.has("billingAddress")) {
      req.setBillingAddress(parse3DSPostalAddress(input, "billingAddress"));
    }
    if (input.has("mobilePhoneNumber")) {
      req.setMobilePhoneNumber(input.getString("mobilePhoneNumber"));
    }
    if (input.has("shippingMethod")) {
      req.setShippingMethod(input.getInt("shippingMethod"));
    }
    if (input.has("accountType") && !input.getString("accountType").equals("00")) {
      req.setAccountType(input.getString("accountType"));
    }
    if (input.has("additionalInformation")) {
      req.setAdditionalInformation(parse3DSAdditionalInformation(input, "additionalInformation"));
    }
    if (input.has("challengeRequested")) {
      req.setChallengeRequested(parseBoolean(input, "challengeRequested", false));
    }
    if (input.has("exemptionRequested")) {
      req.setExemptionRequested(parseBoolean(input, "exemptionRequested", false));
    }
    if (input.has("cardAddChallenge")) {
      req.setCardAddChallengeRequested(input.getBoolean("cardAddChallenge"));
    }

    return req;
  }

  /**
   * Data in JSON:
   * 
   * {
   * "threeDSecureRequest": {
   * }
   * }
   */
  private synchronized void launchDropIn(
      final CallbackContext callbackContext,
      final JSONArray args)
      throws Exception {

    DropInRequest dropInRequest = new DropInRequest();
    if (dropInRequest == null) {
      callbackContext.error("Failed to create DropIn request.");
      return;
    }

    this.dropInCallbackContext = callbackContext;

    JSONObject request = args.getJSONObject(0);
    ThreeDSecureRequest threeDSecureRequest = parseThreeDSecureRequest(request, "threeDSecureRequest");
    if (threeDSecureRequest != null) {
      Log.d(TAG, "Using ThreeDSecureRequest");
      dropInRequest.setThreeDSecureRequest(threeDSecureRequest);
    }
    // not available...
    // dropInRequest.setRequestThreeDSecureVerification(parseBoolean(request,
    // "requestThreeDSecureVerification", false));
    // not available...
    // dropInRequest.setCollectDeviceData(parseBoolean(request,
    // "collectDeviceData",false));

    if (request.has("vaultManager")) {
      dropInRequest.setVaultManagerEnabled(parseBoolean(request, "vaultManager", false));
    }
    if (request.has("cardDisabled")) {
      dropInRequest.setCardDisabled(parseBoolean(request, "cardDisabled", false));
    }
    if (request.has("maskCardNumber")) {
      dropInRequest.setMaskCardNumber(parseBoolean(request, "maskCardNumber", false));
    }
    if (request.has("maskSecurityCode")) {
      dropInRequest.setMaskSecurityCode(parseBoolean(request, "maskSecurityCode", false));
    }
    if (request.has("vaultCardDefaultValue")) {
      dropInRequest.setVaultCardDefaultValue(parseBoolean(request, "vaultCardDefaultValue", true));
    }
    if (request.has("allowVaultCardOverride")) {
      dropInRequest.setAllowVaultCardOverride(parseBoolean(request, "allowVaultCardOverride", false));
    }
    if (request.has("cardholderNameStatus")) {
      dropInRequest.setCardholderNameStatus(parseInt(request, "cardholderNameStatus", 0));
    }

    Log.d(TAG, "calling dropInClient.launchDropIn(dropInRequest)");
    // forceCreateDropInClient(dropInRequest);
    dropInClient.launchDropIn(dropInRequest);
  }

  /**
   * Called when a {@link DropInResult} is created without error.
   * 
   * @param dropInResult a {@link DropInResult}
   */
  @Override
  public void onDropInSuccess(DropInResult dropInResult) {
    Log.d(TAG, "onDropInSuccess");
    // Format paymentMethod
    String paymentMethod = null;
    if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.AMEX) {
      paymentMethod = "AMEX";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.GOOGLE_PAY) {
      paymentMethod = "GOOGLE_PAY";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.DINERS_CLUB) {
      paymentMethod = "DINERS_CLUB";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.DISCOVER) {
      paymentMethod = "DISCOVER";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.JCB) {
      paymentMethod = "JCB";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.MAESTRO) {
      paymentMethod = "MAESTRO";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.MASTERCARD) {
      paymentMethod = "MASTERCARD";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.PAYPAL) {
      paymentMethod = "PAYPAL";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.VISA) {
      paymentMethod = "VISA";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.VENMO) {
      paymentMethod = "VENMO";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.UNIONPAY) {
      paymentMethod = "UNIONPAY";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.HIPER) {
      paymentMethod = "HIPER";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.HIPERCARD) {
      paymentMethod = "HIPERCARD";
    } else if (dropInResult.getPaymentMethodType() == DropInPaymentMethod.UNKNOWN) {
      paymentMethod = "UNKNOWN";
    }

    // Format nonce
    JSONObject paymentMethodNonce = null;
    if (dropInResult.getPaymentMethodNonce() != null) {
      try {
        paymentMethodNonce = new JSONObject()
            .put("isDefault", dropInResult.getPaymentMethodNonce().isDefault())
            .put("nonce", dropInResult.getPaymentMethodNonce().getString());
      } catch (Exception e) {
        e.printStackTrace();
      }
    }

    // Create the JSON object and send result
    try {
      this.sendToDropInContext(new JSONObject()
          .put("paymentMethodType", paymentMethod)
          .put("paymentMethodNonce", paymentMethodNonce)
          .put("deviceData", dropInResult.getDeviceData())
          .put("paymentDescription", dropInResult.getPaymentDescription()));
    } catch (Exception error) {
      error.printStackTrace();
      if (this.dropInCallbackContext != null) {
        this.dropInCallbackContext.error(error.getMessage());
        this.dropInCallbackContext = null;
      }
    }
  }

  /**
   * Called when DropIn has finished with an error.
   * 
   * @param error explains reason for DropIn failure.
   */
  @Override
  public void onDropInFailure(Exception error) {
    Log.d(TAG, "onDropInFailure: " + error.getMessage());
    error.printStackTrace();
    try {
      String message = error.getMessage();
      if (error instanceof UserCanceledException) {
        message = "UserCanceledException|" + message;
      } else if (error instanceof AuthorizationException) {
        message = "AuthorizationException|" + message;
      }
      if (this.dropInCallbackContext != null) {
        this.dropInCallbackContext.error(message);
        this.dropInCallbackContext = null;
      }
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

  // * @param dropInRequest
  // * @param amount
  // * @param currency
  // * @param merchantId
  // *
  // private void enableGooglePay(
  // final DropInRequest dropInRequest,
  // final String amount, String currency, String merchantId) {
  // GooglePaymentRequest googlePaymentRequest = new GooglePaymentRequest()
  // .transactionInfo(TransactionInfo.newBuilder()
  // .setTotalPrice(amount)
  // .setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL)
  // .setCurrencyCode(currency)
  // .build())
  // .billingAddressRequired(true);

  // if (merchantId != null && merchantId.length() > 0) {
  // googlePaymentRequest.googleMerchantId(merchantId);
  // }

  // dropInRequest.googlePaymentRequest(googlePaymentRequest);
  // }

  // private synchronized void presentDropInPaymentUI(
  // final CallbackContext callbackContext,
  // final JSONArray args)
  // throws JSONException {

  // // Ensure the client has been initialized.
  // if (clientToken == null) {
  // _callbackContext
  // .error("The Braintree client must first be initialized "
  // + " via BraintreePlugin.initialize(token)");
  // return;
  // }

  // String btToken = clientToken;
  // clientToken = null;

  // dropInRequest = new DropInRequest().clientToken(btToken);

  // if (dropInRequest == null) {
  // _callbackContext.error(
  // "The Braintree client failed to initialize.");
  // return;
  // }

  // // Ensure we have the correct number of arguments.
  // if (args.length() < 1) {
  // _callbackContext.error("amount is required.");
  // return;
  // }
  // try {
  //// Obtain the arguments.

  // String amount = args.getString(0);

  // if (amount == null) {
  // _callbackContext.error("amount is required.");
  // }

  // String primaryDescription = args.getString(1);

  // JSONObject threeDSecure = args.getJSONObject(2);
  // JSONObject googlePay = args.getJSONObject(3);

  // if (threeDSecure == null) {
  // _callbackContext.error("threeDSecure is required.");
  // }

  // dropInRequest.amount(amount);
  // ThreeDSecureRequest threeDSecureRequest = new ThreeDSecureRequest();
  // threeDSecureRequest.amount(threeDSecure.getString("amount"));
  // threeDSecureRequest.email(threeDSecure.getString("email"));
  // threeDSecureRequest.versionRequested(ThreeDSecureRequest.VERSION_2);
  // dropInRequest.requestThreeDSecureVerification(true);
  // dropInRequest.collectDeviceData(true);
  // dropInRequest.vaultManager(true);
  // dropInRequest.threeDSecureRequest(threeDSecureRequest);

  // if (googlePay != null) {
  // enableGooglePay(
  // dropInRequest, amount, googlePay.getString("currency"),
  // googlePay.getString("merchantId"));
  // }

  // Intent intent = dropInRequest.getIntent(this.cordova.getActivity());

  // if (intent == null) {
  // Log.e(TAG, "presentDropInPaymentUI failed "
  // + "===> unable to create Braintree DropInRequest");
  // _callbackContext
  // .error(TAG + ": presentDropInPaymentUI failed "
  // + "===> unable to create Braintree DropInRequest");
  // return;
  // }

  // this.cordova.startActivityForResult(this, intent,
  // DROP_IN_REQUEST);
  // } catch (Exception e) {
  // Log.e(TAG, "presentDropInPaymentUI failed with error ===> "
  // + e.getMessage());
  // _callbackContext.error(TAG +
  // ": presentDropInPaymentUI failed with error ===> " + e.getMessage());
  // }
  // }

  // private synchronized void paypalRequestOneTimePayment(
  // final JSONArray args) throws Exception {
  // payPalRequest = new PayPalRequest(args.getString(0));
  // payPalRequest.currencyCode(args.getString(1));
  // PayPal.requestOneTimePayment(braintreeFragment, payPalRequest);
  // }

  // private synchronized void paypalRequestBillingAgreement()
  // throws Exception {
  // PayPal.requestBillingAgreement(braintreeFragment, payPalRequest);
  // }

  // Results

  // @Override
  // public void onActivityResult(
  // int requestCode,
  // int resultCode,
  // Intent intent) {
  // super.onActivityResult(requestCode, resultCode, intent);

  // Log.i(TAG, "DropIn Activity Result: "
  // + requestCode + ", " + resultCode);

  // if (_callbackContext == null) {
  // Log.e(TAG,
  // "onActivityResult exiting ==> callbackContext is invalid");
  // return;
  // }

  // if (requestCode == DROP_IN_REQUEST) {

  // PaymentMethodNonce paymentMethodNonce = null;

  // if (resultCode == Activity.RESULT_OK) {
  // if (intent != null) {
  // DropInResult result =
  // intent.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
  // paymentMethodNonce = result.getPaymentMethodNonce();
  // }

  // Log.i(TAG, "DropIn Activity Result: paymentMethodNonce = "
  // + paymentMethodNonce);
  // }

  // // handle errors here, an exception may be available in
  // if (intent != null
  // && intent.getSerializableExtra(DropInActivity.EXTRA_ERROR) != null) {
  // Exception error =
  // (Exception) intent.getSerializableExtra(DropInActivity.EXTRA_ERROR);
  // Log.e(TAG, "onActivityResult exiting "
  // + "==> received error: " + error.getMessage() + "\n"
  // + error.getStackTrace());
  // _callbackContext.error(
  // "onActivityResult exiting ==> received error: " + error.getMessage());
  // return;
  // }
  // if (intent != null) {
  // DropInResult result =
  // intent.getParcelableExtra(DropInResult.EXTRA_DROP_IN_RESULT);
  // String deviceData = result.getDeviceData();
  // this.handleDropInPaymentUiResult(
  // resultCode, paymentMethodNonce, deviceData);
  // return;
  // }
  // _callbackContext.error(
  // "Activity result handler for CUSTOM_REQUEST failed.");
  // return;
  // } else if (requestCode == PAYMENT_BUTTON_REQUEST) {
  // // TODO
  // _callbackContext.error(
  // "Activity result handler for PAYMENT_BUTTON_REQUEST not implemented.");
  // } else if (requestCode == CUSTOM_REQUEST) {
  // _callbackContext.error(
  // "Activity result handler for CUSTOM_REQUEST not implemented.");
  // // TODO
  // } else if (requestCode == PAYPAL_REQUEST) {
  // _callbackContext.error(
  // "Activity result handler for PAYPAL_REQUEST not implemented.");
  // // TODO
  // } else {
  // Log.w(TAG, "onActivityResult exiting ==> requestCode ["
  // + requestCode + "] was unhandled");
  // }
  // }

  /*
   * Helper used to handle the result of the drop-in payment UI.
   *
   * @param resultCode Indicates the result of the UI.
   *
   * @param paymentMethodNonce Information about a successful payment.
   *
   * private void handleDropInPaymentUiResult(
   * final int resultCode,
   * final PaymentMethodNonce paymentMethodNonce,
   * final String deviceData) {
   *
   * Log.i(TAG, "handleDropInPaymentUiResult resultCode ==> "
   * + resultCode + ", paymentMethodNonce = "
   * + paymentMethodNonce);
   * 
   * if (_callbackContext == null) {
   * Log.e(TAG, "handleDropInPaymentUiResult exiting "
   * + "==> callbackContext is invalid");
   * return;
   * }
   * 
   * if (resultCode == Activity.RESULT_CANCELED) {
   * Map<String, Object> resultMap = new HashMap<String, Object>();
   * resultMap.put("userCancelled", true);
   * _callbackContext.success(new JSONObject(resultMap));
   * _callbackContext = null;
   * return;
   * }
   *
   * if (paymentMethodNonce == null) {
   * _callbackContext.error(
   * "Result was not RESULT_CANCELED,"
   * + " but no PaymentMethodNonce was returned from "
   * + "the Braintree SDK (was "
   * + resultCode + ").");
   * _callbackContext = null;
   * return;
   * }
   * 
   * Map<String, Object> resultMap =
   * this.getPaymentUINonceResult(paymentMethodNonce, deviceData);
   * _callbackContext.success(new JSONObject(resultMap));
   * _callbackContext = null;
   * }
   */

  /*
   * Helper used to return a dictionary of values
   * from the given payment method nonce.
   
   * Handles several different types of nonces (eg for cards, PayPal, etc).
   *
   * @param paymentMethodNonce The nonce used to build a dictionary from.
   *
   * @return The dictionary populated via the given payment method nonce.
   *
   * private Map<String, Object> getPaymentUINonceResult(
   * final PaymentMethodNonce paymentMethodNonce,
   * final String deviceData) {
   *
   * Map<String, Object> resultMap = new HashMap<String, Object>();
   *
   * resultMap.put("nonce", paymentMethodNonce.getNonce());
   * resultMap.put("deviceData", deviceData);
   * resultMap.put("type", paymentMethodNonce.getTypeLabel());
   * resultMap.put("localizedDescription",
   * paymentMethodNonce.getDescription());
   *
   * // Card
   * if (paymentMethodNonce instanceof CardNonce) {
   * CardNonce cardNonce = (CardNonce) paymentMethodNonce;
   *
   * Map<String, Object> innerMap = new HashMap<String, Object>();
   * innerMap.put("lastTwo", cardNonce.getLastTwo());
   * innerMap.put("network", cardNonce.getCardType());
   *
   * resultMap.put("card", innerMap);
   * }
   *
   * // PayPal
   * if (paymentMethodNonce instanceof PayPalAccountNonce) {
   * PayPalAccountNonce payPalAccountNonce =
   * (PayPalAccountNonce) paymentMethodNonce;
   *
   * Map<String, Object> innerMap = new HashMap<String, Object>();
   * resultMap.put("email", payPalAccountNonce.getEmail());
   * resultMap.put("firstName", payPalAccountNonce.getFirstName());
   * resultMap.put("lastName", payPalAccountNonce.getLastName());
   * resultMap.put("phone", payPalAccountNonce.getPhone());
   * resultMap.put("clientMetadataId",
   * payPalAccountNonce.getClientMetadataId());
   * resultMap.put("payerId", payPalAccountNonce.getPayerId());
   * 
   * resultMap.put("paypalAccount", innerMap);
   * }
   *
   * // 3D Secure
   * if (paymentMethodNonce instanceof CardNonce) {
   * CardNonce cardNonce = (CardNonce) paymentMethodNonce;
   * ThreeDSecureInfo threeDSecureInfo = cardNonce.getThreeDSecureInfo();
   * 
   * if (threeDSecureInfo != null) {
   * Map<String, Object> innerMap = new HashMap<String, Object>();
   * innerMap.put("liabilityShifted",
   * threeDSecureInfo.isLiabilityShifted());
   * innerMap.put("liabilityShiftPossible",
   * threeDSecureInfo.isLiabilityShiftPossible());
   *
   * resultMap.put("threeDSecureInfo", innerMap);
   * }
   * }
   * 
   * // Venmo
   * if (paymentMethodNonce instanceof VenmoAccountNonce) {
   * VenmoAccountNonce venmoAccountNonce =
   * (VenmoAccountNonce) paymentMethodNonce;
   * 
   * Map<String, Object> innerMap = new HashMap<String, Object>();
   * innerMap.put("username", venmoAccountNonce.getUsername());
   * 
   * resultMap.put("venmoAccount", innerMap);
   * }
   * 
   * return resultMap;
   * }
   * 
   * @Override
   * public void onPaymentMethodNonceCreated(
   * final PaymentMethodNonce paymentMethodNonce) {
   * Log.i(TAG, "onPaymentMethodNonceCreated  ==> paymentMethodNonce = "
   * + paymentMethodNonce);
   * 
   * if (_callbackContext == null) {
   * Log.e(TAG, "onPaymentMethodNonceCreated exiting "
   * + "==> callbackContext is invalid");
   * return;
   * }
   * 
   * try {
   * JSONObject json = new JSONObject();
   * 
   * json.put("nonce", paymentMethodNonce.getNonce().toString());
   * // json.put("deviceData",
   * // DataCollector.collectDeviceData(braintreeFragment));
   * // json.put("deviceData",
   * // DataCollector.collectDeviceData(braintreeFragment,
   * // this));
   * 
   * if (paymentMethodNonce instanceof PayPalAccountNonce) {
   * PayPalAccountNonce pp = (PayPalAccountNonce) paymentMethodNonce;
   * json.put("payerId", pp.getPayerId().toString());
   * json.put("firstName", pp.getFirstName().toString());
   * json.put("lastName", pp.getLastName().toString());
   * }
   * 
   * _callbackContext.sendPluginResult(
   * new PluginResult(PluginResult.Status.OK, json));
   * } catch (Exception e) {
   * Log.e(TAG, "onPaymentMethodNonceCreated  ==> error:"
   * + e.getMessage());
   * e.printStackTrace();
   * }
   * }
   */

  /**
   * Check if a listener has been registered with the "setListener" action.
   *
   * @return true if a listener has been registered.
   */
  public Boolean hasListener() {
    return this.listenerContext != null;
  }

  /**
   * Send a message to the javascript bridge (Braintree.Bridge).
   *
   * @param type Message type / identifer.
   * @param data Message arguments.
   */
  public void sendToListener(final String type, final JSONObject data) {
    try {
      Log.d(TAG, "sendToListener() -> " + type);
      Log.d(TAG, "            data -> " + data.toString());
      if (this.listenerContext == null) {
        return;
      }
      final JSONObject message = new JSONObject().put("type", type);
      if (data != null) {
        message.put("data", data);
      }
      final PluginResult result = new PluginResult(PluginResult.Status.OK, message);
      result.setKeepCallback(true);
      this.listenerContext.sendPluginResult(result);
    } catch (JSONException e) {
      Log.d(TAG, "sendToListener() -> Failed: " + e.getMessage());
    }
  }

  /**
   * Send the response to launchDropIn's registered callback.
   *
   * @param data DropIn.Result in JSON
   */
  public void sendToDropInContext(final JSONObject data) {
    Log.d(TAG, "sendToDropInContext() -> " + data.toString());
    if (this.dropInCallbackContext != null) {
      this.dropInCallbackContext.success(data);
      this.dropInCallbackContext = null;
    }
  }
}
