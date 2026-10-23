# Setting up the TV for fuego

fuego talks to the TV over the network with `adb`, through the TV's **Wireless debugging**. No USB cable is needed. You do this once, and again whenever Wireless debugging gets turned off (a TV restart does that).

> These menu paths are the usual ones on Google TV with Android TV OS 14. They have not been checked on the Fuego TV yet; if a name differs on yours, please open an issue.

## 1. Turn on Developer options

1. On the TV, open **Settings > System > About**.
2. Scroll to **Android TV OS build** and press OK on it seven times. The TV says you are now a developer.
3. Go back to **Settings > System**. **Developer options** now appears there.

## 2. Turn on Wireless debugging

1. Open **Settings > System > Developer options > Wireless debugging**.
2. Turn it on, and allow it when the TV asks.
3. Keep this screen open. It shows the TV's **IP address & Port**, for example `192.168.1.50:41234`.

The TV and your Mac must be on the same network.

## 3. Pair your Mac (once)

1. On the Wireless debugging screen, choose **Pair device with pairing code**. The TV shows a six-digit code and an address with a *pairing* port, for example `192.168.1.50:37099`.
2. On the Mac, while that dialog is open:

   ```sh
   script/fuego pair 192.168.1.50:37099 123456
   ```

   Use the address and code from the dialog. Each code works once.

## 4. Connect

Use the **IP address & Port** from the Wireless debugging screen (not the pairing port):

```sh
script/fuego connect 192.168.1.50:41234
```

Check that your Mac has what it needs with `script/fuego check`.

## When the TV can't be reached

- **After a TV restart**, Wireless debugging is usually off. Turn it back on in **Settings > System > Developer options > Wireless debugging**, then run `fuego connect` again with the address shown there: the port changes each time it is turned on. You don't need to pair again.
- **"Can't reach the TV"** means the Mac can't find it on the network. Check the TV is on, and that the TV and Mac are on the same network.
- **"This Mac isn't paired"** means pairing was lost (for example after a factory reset). Pair again (step 3).

## When you're done

Turn Wireless debugging off in **Settings > System > Developer options > Wireless debugging**. Turn it back on when you want to run fuego again, for example `restore`.
