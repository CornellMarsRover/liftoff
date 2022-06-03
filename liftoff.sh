#!/bin/bash
# The liftoff script will create a CMR development directory and bootstrap it with the entire
# codebase from each code repository. It will then install the command line interface and spin up
# a development daemon.

# Cute little introduction.
echo "🚀 🚀 🚀 🚀"
echo "Hi, I'm Launchpad :) I'll do my best to set up your machine for rover development."

if [[ -z $PKG_MAN ]]; then
    # If the user didn't specify a package manager, try to detect it based on the OS.
    # Launchpad only supports Ubuntu (including on Windows via WSL) and macOS, so only check for those.
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        PKG_MAN="brew"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        PKG_MAN="apt-get"
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows with emulated Linux environment and POSIX compatibility layer
        PKG_MAN="apt-get"
    elif [[ "$OSTYPE" == "msys" ]]; then
        # MinGW (i.e. Windows)
        PKG_MAN="apt-get"
    else
        # Unsupported OS
        echo "Your detected operating system ($OSTYPE) is not supported."
        exit 1
    fi
    echo "Since \$PKG_MAN was not set, I'll use the auto-detected package manager: $PKG_MAN"
fi

# Make sure the package manager actually works.
eval $PKG_MAN &> /dev/null
if [[ $? == 127 ]]; then
    echo "$PKG_MAN was not found. Aborting."
    exit 1
fi

# Make sure git is installed, and try to install it if not.
command -v git >/dev/null 2>&1 ||
{ echo "Git is not installed. Attempting to install...";
  eval "$PKG_MAN install git"
  if [[ $? -ne 0 ]]; then
    echo "Failed to install Git using $PKG_MAN. Aborting."
    exit 1
  fi
}

# Make sure Docker is installed, and tell the user to install it if not.
# Launchpad won't try to install Docker itself because the installation is often not trivial.
command -v docker >/dev/null 2>&1 ||
{ echo "!!!! ERROR !!!!"
  echo "Docker is not installed."
  echo "I can't install it for you because the setup process varies for different systems."
  # TODO: Update this documentation link to the Docker installation page once it's created.
  echo "See this documentation article for steps: https://docs.cornellmarsrover.org/"
  exit 1
}

# Make sure Python 3 is installed and try to install it if not.
command -v python3 >/dev/null 2>&1 ||
{ echo "Python 3 is not installed. Attempting to install..."
  eval "$PKG_MAN install python3"
  if [[ $? -ne 0 ]]; then
    echo "Failed to install Python 3 using $PKG_MAN. Aborting."
    exit 1
  fi
}

# Make sure we have our SSH key set up with GitHub
ssh -T git@github.com &> /dev/null
SSH_KEY_WORKS=$?
if [ $SSH_KEY_WORKS -ne 1 ]; then
    echo "!!!! ERROR !!!!"
    echo "Failed to reach GitHub via SSH. Make sure you set up your SSH key correctly."
    echo "See the following guides for help, and then try running Liftoff again:"
    echo ""
    echo "(1) Creating an SSH key: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent"
    echo ""
    echo "(2) Adding an SSH key to GitHub: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account"
    exit 1
fi

# Check if CMR_ROOT is set and set to its default if not.
if [[ -z $CMR_ROOT ]]; then
    export CMR_ROOT=$HOME/cmr
    PATH_HELP=1
fi

# Create the CMR_ROOT directory if it doesn't already exist.
mkdir -p $CMR_ROOT

# Move to the CMR_ROOT directory
pushd $CMR_ROOT &> /dev/null

# Clone repositories

echo ""
echo "Cloning CMR repositories into $CMR_ROOT:"

for name in launchpad terra phobos-gui phobos-cli micro;
    do
        if [ -d "$CMR_ROOT/$name" ]; then echo "You already have $name, skipping..."
        else 
            echo "Cloning $name from remote..."
            echo "(start git output)"
            git clone "git@github.com:CornellMarsRover/$name.git"
            echo "(end git output)"
            echo "Done cloning $name from remote."
        fi
    done

# Pull down cornellmarsrover/daemon:latest

echo ""
echo "Pulling down the daemon image (latest)..."
docker pull cornellmarsrover/daemon:latest

# Install Phobos CLI from Launchpad's bundled wheel.

# Use "find" to find the wheel file included in Launchpad.
CLI_WHEEL_PATH=$(find launchpad/dist -name "*.whl")
CLI_WHEEL_PATH="$CMR_ROOT/$CLI_WHEEL_PATH"
# Get the CLI version using "awk", which looks for the version number between two dashes (-).
# We only do this for the user's sake, so that they know which version they're getting.
CLI_VERSION=$(basename $CLI_WHEEL_PATH | awk -F '-|-' '{print $2}')
echo ""
echo "Installing Phobos CLI v$CLI_VERSION..."
echo "(start pip output)"
python3 -m pip install --disable-pip-version-check --force-reinstall "$CLI_WHEEL_PATH"
if [[ $? -ne 0 ]]; then
    echo "Failed to install Phobos CLI. Aborting."
    exit 1
fi
echo "(end pip output)"
echo "Done installing Phobos CLI v$CLI_VERSION."

if [[ ! -z $PATH_HELP ]]; then
    echo ""
    echo "!!!! IMPORTANT !!!!"
    echo "I created the CMR root directory in your home folder for you."
    echo "You must manually set the \$CMR_ROOT environment variable in your shell profile by appending this line to it:"
    echo ""
    echo "export CMR_ROOT=$CMR_ROOT"
    echo ""
fi

echo "We have liftoff! Successfully bootstrapped your machine for rover development."

# Go back to whatever directory the user called from (undoes the pushd instruction from earlier)
popd &> /dev/null
