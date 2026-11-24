## Panasonic: dark mode (rofi, GTK, Wi-Fi tray)

Commit "Dark mode by default: rofi in cccru, dark GTK, libadwaita and Qt"
is applied on the gram. still do on panasonic

- [ ] Get the commit: push from the gram (`git push` in ~/dots), then `git pull` on the Panasonic
- [ ] Link the configs:
     ```sh
    mkdir -p ~/.config/rofi ~/.config/gtk-3.0 ~/.config/gtk-4.0
    ln -s ~/dots/rofi/config.rasi          ~/.config/rofi/config.rasi
    ln -s ~/dots/gtk/gtk-3.0/settings.ini  ~/.config/gtk-3.0/settings.ini
    ln -s ~/dots/gtk/gtk-4.0/settings.ini  ~/.config/gtk-4.0/settings.ini
    ```
      (if an ln says file exists check file before replacing)
      
- [ ] networkmgr runs as root, so give root the same GTK setting:
      ```sh
      sudo mkdir -p /root/.config/gtk-3.0
      sudo cp ~/dots/gtk/gtk-3.0/settings.ini /root/.config/gtk-3.0/
      ```
- [ ] Log out, startx
- [ ] Check
