#!/bin/bash
# file: .devcontainer/additions/install-dev-php-laravel.sh
#
# Usage: ./install-dev-php-laravel.sh [options]
#
# Options:
#   --debug     : Enable debug output for troubleshooting
#   --uninstall : Remove installed components instead of installing them
#   --force     : Force installation/uninstallation even if there are dependencies
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="PHP Laravel Development Tools"
SCRIPT_DESCRIPTION="Installs PHP 8.4, Composer, Laravel installer, and sets up Laravel development environment"
SCRIPT_CATEGORY="LANGUAGE_DEV"
CHECK_INSTALLED_COMMAND="command -v php >/dev/null 2>&1 && command -v composer >/dev/null 2>&1 && command -v laravel >/dev/null 2>&1"

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
        # Note: PHP installed via curl script is harder to uninstall cleanly
        echo "⚠️  Note: PHP installed via Herd-lite may require manual removal"
    else
        echo "🔧 Performing pre-installation setup..."

        # Check if PHP is already installed
        if command -v php >/dev/null 2>&1; then
            echo "✅ PHP is already installed (version: $(php --version | head -n 1))"
            
            # Check if Composer is available
            if command -v composer >/dev/null 2>&1; then
                echo "✅ Composer is already installed (version: $(composer --version | head -n 1))"
            fi
            
            # Check if Laravel installer is available
            if command -v laravel >/dev/null 2>&1; then
                echo "✅ Laravel installer is already installed (version: $(laravel --version))"
            fi
        else
            echo "📦 Installing PHP, Composer, and Laravel installer..."
            
            # Install PHP stack using Laravel's official installer
            if ! /bin/bash -c "$(curl -fsSL https://php.new/install/linux/8.4)"; then
                echo "❌ Failed to install PHP stack"
                exit 1
            fi
            
            # Source the bashrc to update PATH for current session
            if [ -f "/home/vscode/.bashrc" ]; then
                echo "🔄 Updating PATH for current session..."
                # shellcheck source=/dev/null
                source /home/vscode/.bashrc
                
                # Also update PATH for this script execution
                export PATH="/home/vscode/.config/herd-lite/bin:$PATH"
            fi
            
            echo "✅ PHP stack installation completed"
        fi

        # Detect if we're in a Laravel project and set up project dependencies
        detect_and_setup_laravel_project
        
        # PATH has been updated in ~/.bashrc for future terminal sessions
        if [ -f "/home/vscode/.bashrc" ]; then
            echo "🔄 PATH has been configured in ~/.bashrc for future terminal sessions"
        fi
    fi
}

# Function to check and fix Vite configuration for devcontainer compatibility
check_and_fix_vite_config() {
    local vite_config="vite.config.js"
    
    if [[ ! -f "$vite_config" ]]; then
        echo "⚠️  No vite.config.js found - skipping Vite configuration check"
        return 0
    fi
    
    # Check if the config already has devcontainer-friendly settings
    if grep -q "host: '0.0.0.0'" "$vite_config" || grep -q 'host: "0.0.0.0"' "$vite_config"; then
        echo "✅ Vite configuration already compatible with devcontainers"
        return 0
    fi
    
    echo "🔍 Checking Vite configuration for devcontainer compatibility..."
    echo "   Current config binds to localhost only, which may cause asset loading issues"
    echo "   in devcontainer environments."
    echo ""
    echo "   Recommended fix: Update vite.config.js to bind to all interfaces (0.0.0.0)"
    echo "   This is safe for development and required for devcontainers."
    echo ""
    
    # In uninstall mode, don't prompt
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        return 0
    fi
    
    # Prompt for permission to update
    read -p "Would you like to update vite.config.js for devcontainer compatibility? (y/N): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⚠️  Vite config not updated. You may experience asset loading issues."
        echo "   If you encounter problems, manually add this to your vite.config.js:"
        echo "   server: { host: '0.0.0.0', port: 5173, hmr: { host: 'localhost' } }"
        return 0
    fi
    
    # Backup the original file
    cp "$vite_config" "${vite_config}.backup"
    echo "📄 Created backup: ${vite_config}.backup"
    
    # Create the updated config
    cat > "$vite_config" << 'EOF'
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    server: {
        host: '0.0.0.0',
        port: 5173,
        hmr: {
            host: 'localhost'
        }
    },
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        tailwindcss(),
    ],
});
EOF
    
    echo "✅ Updated vite.config.js for devcontainer compatibility"
    echo "   - Server now binds to 0.0.0.0 (required for containers)"
    echo "   - HMR configured for localhost (for browser hot reload)"
    echo "   - Original config backed up as ${vite_config}.backup"
}


detect_and_setup_laravel_project() {
    # Check if we're in a Laravel project directory
    if [[ -f "composer.json" && -f "artisan" ]]; then
        echo "🎯 Laravel project detected - setting up project dependencies..."
        
        # Install Composer dependencies if vendor directory doesn't exist or is incomplete
        if [[ ! -d "vendor" || ! -f "vendor/autoload.php" ]]; then
            echo "📦 Installing Composer dependencies..."
            if ! composer install --no-interaction --prefer-dist --optimize-autoloader; then
                echo "❌ Failed to install Composer dependencies"
                return 1
            fi
        else
            echo "✅ Composer dependencies already installed"
        fi
        
        # Install npm dependencies if package.json exists and node_modules is missing/incomplete
        if [[ -f "package.json" ]]; then
            if [[ ! -d "node_modules" || ! -f "package-lock.json" ]]; then
                echo "📦 Installing npm dependencies..."
                if ! npm install; then
                    echo "❌ Failed to install npm dependencies"
                    return 1
                fi
            else
                echo "✅ npm dependencies already installed"
            fi
        fi
        
        # Set up Laravel environment file if it doesn't exist
        if [[ -f ".env.example" && ! -f ".env" ]]; then
            echo "🔧 Creating .env file from .env.example..."
            cp .env.example .env
            
            # Generate app key if it's empty in the .env file
            if ! grep -q "APP_KEY=.*[^=]" .env; then
                echo "🔑 Generating Laravel application key..."
                php artisan key:generate --ansi
            fi
        elif [[ -f ".env" ]]; then
            echo "✅ .env file already exists"
            
            # Check if app key is set, generate if missing
            if ! grep -q "APP_KEY=.*[^=]" .env; then
                echo "🔑 Generating missing Laravel application key..."
                php artisan key:generate --ansi
            fi
        fi
        
        # Create SQLite database file if configured and doesn't exist
        if grep -q "DB_CONNECTION=sqlite" .env 2>/dev/null; then
            local db_path="database/database.sqlite"
            if [[ ! -f "$db_path" ]]; then
                echo "🗄️ Creating SQLite database file..."
                touch "$db_path"
            else
                echo "✅ SQLite database file already exists"
            fi
            
            # Run migrations if the database is empty (check for users table)
            if ! php artisan migrate:status 2>/dev/null | grep -q "users"; then
                echo "🗄️ Running database migrations..."
                if ! php artisan migrate --force --no-interaction; then
                    echo "⚠️  Warning: Database migrations failed - you may need to run them manually"
                fi
            else
                echo "✅ Database migrations already applied"
            fi
        fi
        
        # Check and fix Vite configuration for devcontainer compatibility
        check_and_fix_vite_config
        
        echo "✅ Laravel project setup completed"
    else
        echo "📁 No Laravel project detected in current directory"
        echo "   After installation, you can create a new Laravel project with:"
        echo "   laravel new my-project"
        echo "   or: composer create-project laravel/laravel my-project"
    fi
}

# Define package arrays (Laravel tools are installed via custom logic above)
SYSTEM_PACKAGES=(
    # PHP is installed via curl script, not apt packages
)

NODE_PACKAGES=(
    # Node.js should already be available in the base container
)

PYTHON_PACKAGES=(
    # No Python packages needed for Laravel development
)

PWSH_MODULES=(
    # No PowerShell modules needed for Laravel development
)

# Define VS Code extensions
declare -A EXTENSIONS
EXTENSIONS["bmewburn.vscode-intelephense-client"]="PHP Intelephense|Advanced PHP language support with IntelliSense"
EXTENSIONS["xdebug.php-debug"]="PHP Debug|Debug PHP applications using Xdebug"
EXTENSIONS["neilbrayfield.php-docblocker"]="PHP DocBlocker|Automatically generate PHPDoc comments"
EXTENSIONS["ikappas.composer"]="Composer|Composer dependency manager integration"
EXTENSIONS["mehedidracula.php-namespace-resolver"]="PHP Namespace Resolver|Auto-import and resolve PHP namespaces"
EXTENSIONS["onecentlin.laravel-blade"]="Laravel Blade Snippets|Blade syntax highlighting and snippets"
EXTENSIONS["ryannaddy.laravel-artisan"]="Laravel Artisan|Run Laravel Artisan commands from VS Code"
EXTENSIONS["mtxr.sqltools"]="SQLTools|Database management and SQL query tool"
EXTENSIONS["humao.rest-client"]="REST Client|Send HTTP requests and view responses directly in VS Code"

# Define verification commands to run after installation
VERIFY_COMMANDS=(
    "command -v php >/dev/null && php --version | head -n 1 || echo '❌ PHP not found'"
    "command -v composer >/dev/null && composer --version | head -n 1 || echo '❌ Composer not found'"
    "command -v laravel >/dev/null && laravel --version || echo '❌ Laravel installer not found'"
    "php -m | grep -q 'mbstring' && echo '✅ PHP mbstring extension loaded' || echo '❌ PHP mbstring extension missing'"
    "php -m | grep -q 'curl' && echo '✅ PHP curl extension loaded' || echo '❌ PHP curl extension missing'"
    "php -m | grep -q 'sqlite3' && echo '✅ PHP SQLite extension loaded' || echo '❌ PHP SQLite extension missing'"
)

# Post-installation notes
post_installation_message() {
    local php_version
    local composer_version
    local laravel_version

    if command -v php >/dev/null 2>&1; then
        php_version=$(php --version | head -n 1)
    else
        php_version="not installed"
    fi

    if command -v composer >/dev/null 2>&1; then
        composer_version=$(composer --version | head -n 1)
    else
        composer_version="not installed"
    fi

    if command -v laravel >/dev/null 2>&1; then
        laravel_version=$(laravel --version)
    else
        laravel_version="not installed"
    fi

    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Installed Versions:"
    echo "📋 PHP: $php_version"
    echo "📋 Composer: $composer_version"
    echo "📋 Laravel Installer: $laravel_version"
    echo
    echo "Important Notes:"
    echo "1. Laravel development server runs on http://localhost:8000"
    echo "2. Vite development server runs on http://localhost:5173 (for assets only)"
    echo "3. When VS Code shows port 5173 notification, ignore it - use port 8000"
    echo "4. SQLite is configured as the default database"
    echo "5. SQLTools extension for database management"
    echo "6. REST Client extension for API testing (free, open-source alternative to Postman)"
    echo "7. Vite configuration automatically checked for devcontainer compatibility"
    echo
    echo "Quick Start Commands:"
    echo "- Create new Laravel project: laravel new my-project"
    echo "- Alternative method: composer create-project laravel/laravel my-project"
    echo "- Start development server: composer run dev"
    echo "- Run individual server: php artisan serve"
    echo "- Access Laravel REPL: php artisan tinker"
    echo "- Run migrations: php artisan migrate"
    echo "- Generate controller: php artisan make:controller MyController"
    echo "- Generate model: php artisan make:model MyModel"
    echo "- Run tests: composer run test"
    echo
    echo "Development Workflow:"
    echo "1. Run 'composer run dev' to start all services (recommended)"
    echo "   - Laravel server (port 8000) - your main application"
    echo "   - Vite dev server (port 5173) - hot reload for CSS/JS"
    echo "   - Queue worker - background job processing"
    echo "   - Log viewer - real-time log monitoring"
    echo "2. Open http://localhost:8000 in your browser"
    echo "3. Edit files - Vite will automatically reload CSS/JS changes"
    echo
    echo "Documentation Links:"
    echo "- Laravel Documentation: https://laravel.com/docs/12.x"
    echo "- Laravel Installation Guide: https://laravel.com/docs/12.x/installation"
    echo "- PHP Documentation: https://www.php.net/docs.php"
    echo "- Composer Documentation: https://getcomposer.org/doc/"

    # Show PATH information
    echo
    echo "Environment Information:"
    echo "📁 PHP binaries location: /home/vscode/.config/herd-lite/bin"
    echo "🔄 PATH has been configured in ~/.bashrc"
    
    # Show Laravel project status if detected
    if [[ -f "composer.json" && -f "artisan" ]]; then
        echo
        echo "Laravel Project Status:"
        if [[ -f ".env" ]]; then
            echo "✅ Environment file configured"
        else
            echo "⚠️  No .env file - copy from .env.example and run 'php artisan key:generate'"
        fi
        
        if [[ -d "vendor" ]]; then
            echo "✅ Composer dependencies installed"
        else
            echo "⚠️  Run 'composer install' to install dependencies"
        fi
        
        if [[ -f "database/database.sqlite" ]]; then
            echo "✅ SQLite database file exists"
        else
            echo "⚠️  Run 'touch database/database.sqlite' to create database file"
        fi
    fi
    
    # Show next steps at the very end
    echo
    echo "🚀 Next Steps:"
    echo "1. Run: source ~/.bashrc"
    echo "2. Then: composer run dev"
    echo "3. Open http://localhost:8000 in your browser"
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. PHP installed via Herd-lite remains in ~/.config/herd-lite/"
    echo "2. Composer cache remains in ~/.composer/"
    echo "3. Laravel project files remain unchanged"
    echo "4. VS Code extensions have been removed"
    echo "5. See Laravel documentation for complete removal steps if needed"

    # Check for remaining components
    echo
    echo "Checking for remaining components..."

    if command -v php >/dev/null 2>&1; then
        echo
        echo "⚠️  Warning: PHP is still installed"
        echo "To completely remove PHP installed via Herd-lite:"
        echo "  rm -rf ~/.config/herd-lite"
        echo "  # Then edit ~/.bashrc to remove the PATH entry"
    fi

    if command -v composer >/dev/null 2>&1; then
        echo
        echo "⚠️  Warning: Composer is still installed"
        echo "Composer cache location: ~/.composer/"
    fi

    if command -v laravel >/dev/null 2>&1; then
        echo
        echo "⚠️  Warning: Laravel installer is still installed"
        echo "This is part of the Herd-lite installation"
    fi

    # Check for remaining VS Code extensions
    local extensions=(
        "bmewburn.vscode-intelephense-client"
        "xdebug.php-debug"
        "neilbrayfield.php-docblocker"
        "ikappas.composer"
        "mehedidracula.php-namespace-resolver"
        "onecentlin.laravel-blade"
        "ryannaddy.laravel-artisan"
        "mtxr.sqltools"
        "humao.rest-client"
    )

    local has_extensions=0
    for ext in "${extensions[@]}"; do
        if code --list-extensions | grep -q "$ext"; then
            if [ $has_extensions -eq 0 ]; then
                echo
                echo "⚠️  Note: Some VS Code extensions are still installed:"
                has_extensions=1
            fi
            echo "- $ext"
        fi
    done

    if [ $has_extensions -eq 1 ]; then
        echo "These were not automatically removed during uninstallation."
    fi
}

#------------------------------------------------------------------------------
# STANDARD SCRIPT LOGIC - Do not modify anything below this line
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags for core scripts
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

# Source all core installation scripts
source "$(dirname "$0")/core-install-apt.sh"
source "$(dirname "$0")/core-install-node.sh"
source "$(dirname "$0")/core-install-extensions.sh"
source "$(dirname "$0")/core-install-pwsh.sh"
source "$(dirname "$0")/core-install-python-packages.sh"

# Function to process installations
process_installations() {
    # Process each type of package if array is not empty
    if [ ${#SYSTEM_PACKAGES[@]} -gt 0 ]; then
        process_system_packages "SYSTEM_PACKAGES"
    fi

    if [ ${#NODE_PACKAGES[@]} -gt 0 ]; then
        process_node_packages "NODE_PACKAGES"
    fi

    if [ ${#PYTHON_PACKAGES[@]} -gt 0 ]; then
        process_python_packages "PYTHON_PACKAGES"
    fi

    if [ ${#PWSH_MODULES[@]} -gt 0 ]; then
        process_pwsh_modules "PWSH_MODULES"
    fi

    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        process_extensions "EXTENSIONS"
    fi
}

# Function to verify installations
verify_installations() {
    if [ ${#VERIFY_COMMANDS[@]} -gt 0 ]; then
        echo
        echo "🔍 Verifying installations..."
        for cmd in "${VERIFY_COMMANDS[@]}"; do
            echo "Running: $cmd"
            if ! eval "$cmd"; then
                echo "❌ Verification failed for: $cmd"
            fi
        done
    fi
}

# Main execution
if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    echo "🔄 Starting uninstallation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        for ext_id in "${!EXTENSIONS[@]}"; do
            IFS='|' read -r name description _ <<< "${EXTENSIONS[$ext_id]}"
            check_extension_state "$ext_id" "uninstall" "$name"
        done
    fi
    post_uninstallation_message
else
    echo "🔄 Starting installation process for: $SCRIPT_NAME"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    pre_installation_setup
    process_installations
    verify_installations
    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        # Extensions installed successfully - VS Code will activate them after reload
        echo "✅ All extensions installed - restart VS Code to activate"
    fi
    post_installation_message
fi