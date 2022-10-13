package cc.fovea;

import android.util.Log;
import com.braintreepayments.api.ClientTokenCallback;
import com.braintreepayments.api.ClientTokenProvider;
import org.json.JSONObject;

/**
 * Implements a Token provider that asks javascript for a token.
 *
 * Sending event "getClientToken" to javascript, waits for a response and
 * report it to Braintree.
 */
public final class BraintreeTokenProvider implements ClientTokenProvider {

    /** Link to the parent plugin instance. */
    private BraintreePlugin plugin;

    /** Callback for the last all to getClientToken. */
    private ClientTokenCallback callback;

    /**
     * Constructor.
     *
     * @param pPlugin Parent plugin.
     */
    BraintreeTokenProvider(final BraintreePlugin pPlugin) {
        this.plugin = pPlugin;
    }

    /**
     * Implements ClientTokenProvider.
     *
     * @param pCallback Callback to call with the response or error.
     */
    public void getClientToken(final ClientTokenCallback pCallback) {

        this.callback = pCallback;

        if (!this.plugin.hasListener()) {
            Log.d(BraintreePlugin.TAG,
                    "BraintreeTokenProvider.getClientToken() => failure: "
                            + "plugin not initialized yet.");
            pCallback.onFailure(new Exception(
                    "Braintree ClientTokenProvider not provided."));
            return;
        }

        Log.d(BraintreePlugin.TAG, "BraintreeTokenProvider.getClientToken()");
        this.plugin.sendToListener("getClientToken", new JSONObject());
    }

    /**
     * Called with the response from the JS ClientTokenProvider.
     *
     * @param clientToken Value for the client token fetched from server.
     */
    public void onClientTokenSuccess(final String clientToken) {
        if (this.callback != null) {
            Log.d(BraintreePlugin.TAG,
                "BraintreeTokenProvider.success(" + clientToken + ")");
            this.callback.onSuccess(clientToken);
            this.callback = null;
        }
    }

    /**
     * Called with the error from the JS ClientTokenProvider.
     *
     * @param message Human readable error description.
     */
    public void onClientTokenFailure(final String message) {
        if (this.callback != null) {
            Log.d(BraintreePlugin.TAG,
                "BraintreeTokenProvider.failure(" + message + ")");
            callback.onFailure(new Exception(message));
            this.callback = null;
        }
    }
}
