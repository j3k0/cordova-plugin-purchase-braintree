#!/bin/sh
(
  find src/ios/BraintreeDropIn -name '*.m' \
    | awk '
      {
        split($0, a, "/");
        print "        <source-file src=\"" $0 "\" target-dir=\"" a[length(a) - 1] "\" compiler-flags=\"-I$PROJECT_DIR/$PROJECT_NAME/Plugins/cordova-plugin-purchase-braintree/\" />";
      }'
  find src/ios/BraintreeDropIn -name '*.h' \
    | awk '
      {
        split($0, a, "/");
        print "        <header-file src=\"" $0 "\" target-dir=\"" a[length(a) - 1] "\" />";
      }'
) \
  | pbcopy

echo "List of source files added to your clipboard".
