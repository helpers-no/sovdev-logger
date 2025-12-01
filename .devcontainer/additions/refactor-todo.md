# Refactor TODO list

This file contains stuff that we need to do before we are finished refactoring.

## Standard version checking function

The script install-dev-golang.sh has a function get_installed_go_version() that checks the version and return it.
The other functions dont and they should.
TODO: add a sommon named function in the template that all scripts call to get this information.

## auto_enable_tool and auto_disable_tool
Manages addition and removal from .devcontainer.extend/enabled-tools.conf 
TODO: All scripts must use these functions. and template _template-install-script.sh must be updated so that all new scripts follow the rules.
TODO: apparently functions dont need parameters so those can be removed

## --debug  flag
Some scripts have the --debug flag and some not. why?
Do the system support it/do we need it

## PREREQUISITE_CONFIGS automatic enforcement
The template defines PREREQUISITE_CONFIGS field and lib/prerequisite-check.sh library exists, but automatic checking is not yet implemented in dev-setup.sh or project-installs.sh.
TODO: Implement automatic prerequisite checking before running install scripts (see template lines 52-86 and TODO in config-ai-claudecode.sh)
TODO: Once implemented, remove manual prerequisite checks from pre_installation_setup() functions and rely on PREREQUISITE_CONFIGS declaration instead