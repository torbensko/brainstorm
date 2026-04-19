import type { ForgeConfig } from "@electron-forge/shared-types";
import { MakerSquirrel } from "@electron-forge/maker-squirrel";
import { MakerZIP } from "@electron-forge/maker-zip";
import { MakerDMG } from "@electron-forge/maker-dmg";
import { MakerDeb } from "@electron-forge/maker-deb";
import { MakerRpm } from "@electron-forge/maker-rpm";
import { VitePlugin } from "@electron-forge/plugin-vite";
import path from "path";

const config: ForgeConfig = {
  packagerConfig: {
    asar: true,
    ...(process.env.CODESIGN_IDENTITY && {
      osxSign: {
        identity: process.env.CODESIGN_IDENTITY,
        optionsForFile: () => ({
          entitlements: path.resolve("entitlements.mac.plist"),
          hardenedRuntime: true,
        }),
      },
      osxNotarize: {
        appleId: process.env.APPLE_ID!,
        appleIdPassword: process.env.APPLE_ID_PASSWORD!,
        teamId: process.env.APPLE_TEAM_ID!,
      },
    }),
  },
  rebuildConfig: {},
  makers: [
    new MakerSquirrel({}),
    new MakerZIP({}, ["darwin"]),
    new MakerDMG({}),
    new MakerDeb({}),
    new MakerRpm({}),
  ],
  plugins: [
    new VitePlugin({
      build: [
        {
          entry: "electron/main.ts",
          config: "vite.main.config.mjs",
          target: "main",
        },
        {
          entry: "electron/preload.ts",
          config: "vite.preload.config.mjs",
          target: "preload",
        },
      ],
      renderer: [
        {
          name: "main_window",
          config: "vite.renderer.config.mjs",
        },
      ],
    }),
  ],
};

export default config;
