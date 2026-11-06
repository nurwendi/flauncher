/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:isolate';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flauncher/database.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/unsplash_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unsplash_client/unsplash_client.dart';

import 'flauncher_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Paint.enableDithering = true;

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDummyKeyForOfflineInit1234567890",
        appId: "1:100000000000:android:0000000000000000000000",
        messagingSenderId: "100000000000",
        projectId: "flauncher-custom",
      ),
    );
  } catch (_) {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  }
  final firebaseCrashlytics = FirebaseCrashlytics.instance;

  FlutterError.onError = (details) {
    try {
      firebaseCrashlytics.recordFlutterError(details);
    } catch (_) {}
  };
  Isolate.current.addErrorListener(RawReceivePort((List<dynamic> pair) async => await firebaseCrashlytics.recordError(
        pair.first,
        pair.last as StackTrace,
      )).sendPort);

  runZonedGuarded<void>(() async {
    final firebaseAnalytics = FirebaseAnalytics.instance;
    final sharedPreferences = await SharedPreferences.getInstance();
    final imagePicker = ImagePicker();
    final fLauncherChannel = FLauncherChannel();
    final remoteConfig = await _initFirebaseRemoteConfig();
    final fLauncherDatabase = FLauncherDatabase(connect());
    final unsplashService = UnsplashService(
      UnsplashClient(
        settings: ClientSettings(
          debug: kDebugMode,
          credentials: AppCredentials(
            accessKey: remoteConfig.getString("unsplash_access_key"),
            secretKey: remoteConfig.getString("unsplash_secret_key"),
          ),
        ),
      ),
    );
    runApp(
      FLauncherApp(
        sharedPreferences,
        firebaseCrashlytics,
        firebaseAnalytics,
        imagePicker,
        fLauncherChannel,
        fLauncherDatabase,
        unsplashService,
        remoteConfig,
      ),
    );
  }, firebaseCrashlytics.recordError);
}

Future<FirebaseRemoteConfig> _initFirebaseRemoteConfig() async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  try {
    await remoteConfig.setDefaults({"unsplash_enabled": false, "unsplash_access_key": "", "unsplash_secret_key": ""});
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration(minutes: 1),
        minimumFetchInterval: kReleaseMode ? Duration(hours: 6) : Duration.zero,
      ),
    );
    await remoteConfig.ensureInitialized();
    await remoteConfig.fetchAndActivate();
  } catch (_) {}
  return remoteConfig;
}
