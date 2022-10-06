NODE_MODULES?=node_modules

help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "available targets:"
	@echo "    build ............. Generate javascript files for iOS and Android."
	@echo "    tests ............. Run all tests."
	@echo "    clean ............. Cleanup the project (temporary and generated files)."
	@echo ""
	@echo "extra targets"
	@echo "    all ............ Generate javascript files and documentation"
	@echo ""
	@echo "(c)2014-2019, Jean-Christophe Hoelt <hoelt@fovea.cc>"
	@echo ""

all: build doc

build: javalint check-tsc compile test-js

compile:
	@echo "- Compiling TypeScript"
	@${NODE_MODULES}/.bin/tsc

# for backward compatibility
proprocess: compile

.checkstyle.jar:
	curl "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-10.3.4/checkstyle-10.3.4-all.jar" -o .checkstyle.jar -L

javalint: .checkstyle.jar
	java -jar .checkstyle.jar -c /sun_checks.xml src/android/*.java

tests: test-js test-install
	@echo 'ok'

clean:
	@find . -name '*~' -exec rm '{}' ';'

todo:
	@grep -rE "TODO|XXX" src/ts src/android src/ios src/windows
