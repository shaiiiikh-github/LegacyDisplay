# Building & Installing LegacyDisplay on iOS 12.5.8 (Without a Mac)

This guide documents the zero-cost installation workflow to sign and install LegacyDisplay on an **iPad Air 1st generation (iOS 12.5.8)** from a Windows machine using a standard USB cable and a free Apple ID.

---

## 1. Prerequisites (Windows Machine)

1. **GitHub CLI (`gh`)**: Installed and authenticated (`gh auth status`).
2. **iTunes for Windows (Non-Microsoft Store version)**:
   - Needed for Apple Mobile Device Support USB drivers.
   - Download the standalone installer: [iTunes 64-bit for Windows](https://www.apple.com/itunes/download/win64).
   - *Note*: If iCloud for Windows is installed from the Windows Store, uninstall it and install the standalone package.
3. **Sideloadly (Recommended for iOS 12.5.8)**:
   - Download from [sideloadly.io](https://sideloadly.io/).
   - Sideloadly natively supports iOS 12.x devices, ARM64 binaries, and free Apple IDs directly over USB.
4. **Apple ID**: Any standard free personal Apple ID.

---

## 2. Step 1: Download the Unsigned IPA from GitHub Actions

From PowerShell in `D:\Projects\LegacyDisplay`:

```powershell
# 1. List latest successful workflow runs
gh run list --workflow="iOS Build & Test" --status=success --limit=1

# 2. Download the packaged IPA artifact
gh run download --name="LegacyDisplay-unsigned-ipa" --dir="artifacts"

# 3. Verify the downloaded IPA
Get-ChildItem -Path "artifacts"
```
The artifact `LegacyDisplay-unsigned.ipa` will be extracted into the `artifacts/` folder.

---

## 3. Step 2: Connect iPad to Windows PC

1. Connect the iPad Air (iOS 12.5.8) to your Windows PC using an Apple Lightning-to-USB cable.
2. If prompted on the iPad: *"Trust This Computer?"*, tap **Trust** and enter your iPad passcode.
3. Open iTunes to confirm the iPad appears and is recognized.

---

## 4. Step 3: Sideload & Sign with Sideloadly

1. Launch **Sideloadly**.
2. Drag and drop `artifacts\LegacyDisplay-unsigned.ipa` into the IPA icon box in Sideloadly.
3. Under **User Account**, enter your Apple ID email.
4. Ensure your iPad Air is selected under **iDevice**.
5. Click **Start**.
6. When prompted, enter your Apple ID password and 2FA verification code.
   *(Sideloadly signs the application locally using Apple's free developer provisioning profile).*
7. Wait until Sideloadly displays **Done**. The **LegacyDisplay** app icon will appear on your iPad home screen.

---

## 5. Step 4: Trust the Developer Profile on iPad

Before the app can be opened for the first time on iOS 12.5.8:
1. On the iPad, open **Settings > General > Device Management** (or **Profiles & Device Management**).
2. Tap your Apple ID email under *Developer App*.
3. Tap **Trust "[Your Apple ID]"** and confirm **Trust**.
4. Return to the home screen and launch **LegacyDisplay**.

---

## 6. Free Apple ID Limitations & Maintenance

- **7-Day Expiry**: Free developer provisioning certificates expire after 7 days. When expired, re-run Sideloadly to re-sign and refresh the app (app data and profiles are preserved).
- **3 Active App Limit**: Free Apple IDs allow up to 3 sideloaded apps at a time per device.
- **Security**: Never commit Apple ID credentials, certificates, or provisioning profiles to Git.
