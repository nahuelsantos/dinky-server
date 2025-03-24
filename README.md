## Intro
This document contains all the information for dinky administration

### Set up
#### Install NeoVim
```bash
sudo apt install neovim git
```
#### Install zsh
First install zsh
```bash
sudo apt install zsh
```
Make zsh the default shell
```bash
sudo chsh -s "$(command -v zsh)" "${USER}"
```
Restart the terminal and enter “2” to populate your ZSH configuration file with the recommended settings.
#### Install oh my zsh
```zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```
##### Add plugins
###### Autosuggestions
```zsh
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
```
###### Syntax highlighting
```zsh
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
```
Add the plugins to the .zshrc config file
```zsh
nvim ~/.zshrc
```
Find the `plugins` setting in the configuration file and add `zsh-autosuggestions` and `zsh-syntax-highlighting` to the list of plugins. The setting should look like this:
```zsh
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
```
##### Add Dracula theme (optional)
```zsh
git clone https://github.com/dracula/zsh.git  ~/.oh-my-zsh/themes/dracula
```
```zsh
ln -s ~/.oh-my-zsh/themes/dracula/dracula.zsh-theme ~/.oh-my-zsh/themes/dracula.zsh-theme
```
Go to your `~/.zshrc` file and set `ZSH_THEME="dracula"`.

#### Install docker
```zsh
curl -fsSL https://get.docker.com -o get-docker.sh 
sudo sh get-docker.sh 
sudo usermod -aG docker $USER # Add your user to the docker group (log out and back in after this) 
sudo apt install -y libffi-dev libssl-dev python3-pip 
```

#### Install firewall
```zsh
sudo apt install ufw
```
Run the script
```bash
sudo bash firewall/setup-firewall.sh
```

### Create Docker network
```bash
docker network create traefik_network
```
