# ChromeOS VM Kernel Builder

A Nix-based toolkit to build custom kernels for ChromeOS Crostini and Baguette containers, enabling support for Waydroid (Binder/Ashmem).

## Prerequisites
* **Share Downloads:** Open the ChromeOS "Files" app, right-click **Downloads**, and select **"Share with Linux"**. This allows the builder to save the kernel directly to your host.

## How to use

1.  **Enter the Environment:**
    ```bash
    nix develop
    ```

2.  **Setup & Configure:**
    Download the source and extract the configuration from your running kernel to ensure an exact match.
    ```bash
    just setup
    just config
    ```

3.  **Enable Waydroid:**
    Open the menu and enable **Android Drivers**, **Binder IPC**, and **BinderFS**.
    ```bash
    just menuconfig
    ```

4.  **Build the Kernel:**
    ```bash
    just build
    ```

5.  **Deploy:**
    Copy the kernel directly to your ChromeOS Downloads folder.
    ```bash
    just deploy
    ```

6.  **Boot (On Host):**
    Open Crosh (`Ctrl+Alt+T`) on your Chromebook and run:
    ```bash
    vmc stop baguette
    vmc start --vm-type BAGUETTE --kernel /home/chronos/user/MyFiles/Downloads/bzImage baguette
    ```
