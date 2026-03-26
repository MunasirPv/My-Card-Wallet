# My Card Wallet

A secure digital card wallet application built with Flutter, designed to securely store and manage your credit/debit card details with advanced features like biometric authentication, card scanning, and NFC payment emulation.

## ✨ Features

-   **Secure Storage:** Encrypted storage for all sensitive card details.
-   **Biometric/PIN Authentication:** Protect access to your wallet and sensitive card information (number, CVV) with your device's biometric sensors or a custom PIN.
-   **Manual Card Entry:** Easily add card details by typing them in.
-   **Card Scanning (OCR):** Quickly add new cards by scanning them with your device's camera.
-   **NFC Payment Emulation (Android Only):** Temporarily activate a stored card for contactless payments at compatible terminals.
-   **Interactive Card Display:**
    -   Fluid 3D flip animation to view card front and back.
    -   Tap to reveal card number (after authentication).
    -   Tap to reveal CVV on the back (after authentication).
-   **Card Management:**
    -   Swipe to edit: Quickly navigate to the edit screen for a card.
    -   Swipe to delete: Securely remove cards with a confirmation.
    -   Long press for more options (Edit/Delete).
-   **Theming:** Modern UI with support for various card networks (Visa, Mastercard, Amex, etc.).
-   **Custom PIN Dialog:** Seamless and secure PIN entry experience consistent with the app's design.

## 🚀 Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

-   [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.11.0 or higher)
-   [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter plugins.
-   A device or emulator with NFC capabilities (for testing NFC features on Android).

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/MunasirPv/My-Card-Wallet.git
    cd My-Card-Wallet
    ```

2.  **Fetch dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run code generation (for Riverpod, Freezed, etc.):**
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

4.  **Run the application:**
    ```bash
    flutter run
    ```
    For Android NFC HCE testing, ensure you run on a physical Android device with NFC enabled.

## ⚙️ Android Specific Setup for NFC HCE

The NFC payment emulation feature is **Android-only**.
Ensure your `android/app/src/main/AndroidManifest.xml` and `android/app/src/main/res/xml/apduservice.xml` are correctly configured as per the project.

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 📧 Contact

Your Name - [@your_twitter](https://twitter.com/your_twitter) - your_email@example.com

Project Link: [https://github.com/MunasirPv/My-Card-Wallet](https://github.com/MunasirPv/My-Card-Wallet)
