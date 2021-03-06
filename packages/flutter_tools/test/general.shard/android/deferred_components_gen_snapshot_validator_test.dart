// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:file/memory.dart';
import 'package:flutter_tools/src/android/deferred_components_gen_snapshot_validator.dart';
import 'package:flutter_tools/src/android/deferred_components_validator.dart';
import 'package:flutter_tools/src/base/deferred_component.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/build_system/targets/common.dart';
import 'package:flutter_tools/src/globals.dart' as globals;

import '../../src/common.dart';

void main() {
  FileSystem fileSystem;
  BufferLogger logger;
  Environment env;

  Environment createEnvironment() {
    final Map<String, String> defines = <String, String>{ kSplitAot: 'true' };
    final Environment result = Environment(
      outputDir: fileSystem.directory('/output'),
      buildDir: fileSystem.directory('/build'),
      projectDir: fileSystem.directory('/project'),
      defines: defines,
      inputs: <String, String>{},
      cacheDir: fileSystem.directory('/cache'),
      flutterRootDir: fileSystem.directory('/flutter_root'),
      artifacts: globals.artifacts,
      fileSystem: fileSystem,
      logger: logger,
      processManager: globals.processManager,
      engineVersion: 'invalidEngineVersion',
      generateDartPluginRegistry: false,
    );
    return result;
  }

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    logger = BufferLogger.test();
    env = createEnvironment();
  });

  testWithoutContext('No checks passes', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    validator.displayResults();
    validator.attemptToolExit();
    expect(logger.statusText, 'test check passed.\n');
  });

  testWithoutContext('writeCache passes', () async {
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    validator.writeLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 2, libraries: <String>['lib1']),
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText, 'test check passed.\n');

    final File expectedFile = env.projectDir.childFile('deferred_components_loading_units.yaml');

    expect(expectedFile.existsSync(), true);
    const String expectedContents =
'''
loading-units:
  - id: 2
    libraries:
      - lib1
  - id: 3
    libraries:
      - lib2
      - lib3
''';
    expect(expectedFile.readAsStringSync().contains(expectedContents), true);
  });

  testWithoutContext('loadingUnitCache identical passes', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units:
  - id: 2
    libraries:
      - lib1
  - id: 3
    libraries:
      - lib2
      - lib3
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 2, libraries: <String>['lib1']),
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ]
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText, 'test check passed.\n');
  });

  testWithoutContext('loadingUnitCache finds new loading units', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units:
  - id: 3
    libraries:
      - lib2
      - lib3
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 2, libraries: <String>['lib1']),
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('New loading units were found:\n\n  LoadingUnit 2\n    Libraries:\n    - lib1\n'), true);
  });

  testWithoutContext('loadingUnitCache finds missing loading units', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units:
  - id: 2
    libraries:
      - lib1
  - id: 3
    libraries:
      - lib2
      - lib3
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Previously existing loading units no longer exist:\n\n  LoadingUnit 2\n    Libraries:\n    - lib1\n'), true);
  });

  testWithoutContext('missing cache file counts as all new loading units', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 2, libraries: <String>['lib1']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('New loading units were found:\n\n  LoadingUnit 2\n    Libraries:\n    - lib1\n'), true);
  });

  testWithoutContext('loadingUnitCache validator detects malformed file: missing main entry', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units-spelled-wrong:
  - id: 2
    libraries:
      - lib1
  - id: 3
    libraries:
      - lib2
      - lib3
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Errors checking the following files:'), true);
    expect(logger.statusText.contains('Invalid loading units yaml file, \'loading-units\' entry did not exist.'), true);

    expect(logger.statusText.contains('Previously existing loading units no longer exist:\n\n  LoadingUnit 2\n    Libraries:\n    - lib1\n'), false);
  });

  testWithoutContext('loadingUnitCache validator detects malformed file: not a list', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units: hello
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Errors checking the following files:'), true);
    expect(logger.statusText.contains('Invalid loading units yaml file, \'loading-units\' is not a list.'), true);
  });

  testWithoutContext('loadingUnitCache validator detects malformed file: not a list', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units:
  - 2
  - 3
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Errors checking the following files:'), true);
    expect(logger.statusText.contains('Invalid loading units yaml file, \'loading-units\' is not a list of maps.'), true);
  });

  testWithoutContext('loadingUnitCache validator detects malformed file: missing id', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units:
  - id: 2
    libraries:
      - lib1
  - libraries:
      - lib2
      - lib3
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Errors checking the following files:'), true);
    expect(logger.statusText.contains('Invalid loading units yaml file, all loading units must have an \'id\''), true);
  });

  testWithoutContext('loadingUnitCache validator detects malformed file: libraries is list', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units:
  - id: 2
    libraries:
      - lib1
  - id: 3
    libraries: hello
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Errors checking the following files:'), true);
    expect(logger.statusText.contains('Invalid loading units yaml file, \'libraries\' is not a list.'), true);
  });

  testWithoutContext('loadingUnitCache validator detects malformed file: libraries is list of strings', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units:
  - id: 2
    libraries:
      - lib1
  - id: 3
    libraries:
      - blah: hello
        blah2: hello2
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Errors checking the following files:'), true);
    expect(logger.statusText.contains('Invalid loading units yaml file, \'libraries\' is not a list of strings.'), true);
  });

  testWithoutContext('loadingUnitCache validator detects malformed file: empty libraries allowed', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final File cacheFile = env.projectDir.childFile(DeferredComponentsValidator.kLoadingUnitsCacheFileName);
    if (cacheFile.existsSync()) {
      cacheFile.deleteSync();
    }
    cacheFile.createSync(recursive: true);
    cacheFile.writeAsStringSync('''
loading-units:
  - id: 2
    libraries:
      - lib1
  - id: 3
    libraries:
''', flush: true, mode: FileMode.append);
    validator.checkAgainstLoadingUnitsCache(
      <LoadingUnit>[
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Errors checking the following files:'), false);
  });

  testWithoutContext('androidStringMapping modifies strings file', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final Directory baseModuleDir = env.projectDir.childDirectory('android').childDirectory('app');
    final File manifest = baseModuleDir.childDirectory('src').childDirectory('main').childFile('AndroidManifest.xml');
    if (manifest.existsSync()) {
      manifest.deleteSync();
    }
    manifest.createSync(recursive: true);
    manifest.writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.splitaot">
    <application
        android:name="io.flutter.app.FlutterPlayStoreSplitApplication"
        android:label="splitaot"
        android:extractNativeLibs="false">
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:windowSoftInputMode="adjustResize">
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
        <meta-data
            android:name="io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager.loadingUnitMapping"

            android:value="invalidmapping"

            />
    </application>
</manifest>
''', flush: true, mode: FileMode.append);
    validator.checkAppAndroidManifestComponentLoadingUnitMapping(
      <DeferredComponent>[
        DeferredComponent(name: 'component1', libraries: <String>['lib2']),
        DeferredComponent(name: 'component2', libraries: <String>['lib1', 'lib4']),
      ],
      <LoadingUnit>[
        LoadingUnit(id: 2, libraries: <String>['lib1']),
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
        LoadingUnit(id: 4, libraries: <String>['lib4', 'lib5']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Modified android files:\n'), true);
    expect(logger.statusText.contains('build/${DeferredComponentsValidator.kDeferredComponentsTempDirectory}/app/src/main/AndroidManifest.xml\n'), true);

    final File manifestOutput = env.projectDir
      .childDirectory('build')
      .childDirectory(DeferredComponentsValidator.kDeferredComponentsTempDirectory)
      .childDirectory('app')
      .childDirectory('src')
      .childDirectory('main')
      .childFile('AndroidManifest.xml');
    expect(manifestOutput.existsSync(), true);
    expect(manifestOutput.readAsStringSync().contains('<meta-data android:name="io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager.loadingUnitMapping" android:value="3:component1,2:component2,4:component2"/>'), true);
    expect(manifestOutput.readAsStringSync().contains('android:value="invalidmapping"'), false);
    expect(manifestOutput.readAsStringSync().contains('<!-- Don\'t delete the meta-data below.'), true);
  });

  testWithoutContext('androidStringMapping adds mapping when no existing mapping', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final Directory baseModuleDir = env.projectDir.childDirectory('android').childDirectory('app');
    final File manifest = baseModuleDir.childDirectory('src').childDirectory('main').childFile('AndroidManifest.xml');
    if (manifest.existsSync()) {
      manifest.deleteSync();
    }
    manifest.createSync(recursive: true);
    manifest.writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.splitaot">
    <application
        android:name="io.flutter.app.FlutterPlayStoreSplitApplication"
        android:label="splitaot"
        android:extractNativeLibs="false">
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:windowSoftInputMode="adjustResize">
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
''', flush: true, mode: FileMode.append);
    validator.checkAppAndroidManifestComponentLoadingUnitMapping(
      <DeferredComponent>[
        DeferredComponent(name: 'component1', libraries: <String>['lib2']),
        DeferredComponent(name: 'component2', libraries: <String>['lib1', 'lib4']),
      ],
      <LoadingUnit>[
        LoadingUnit(id: 2, libraries: <String>['lib1']),
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
        LoadingUnit(id: 4, libraries: <String>['lib4', 'lib5']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Modified android files:\n'), true);
    expect(logger.statusText.contains('build/${DeferredComponentsValidator.kDeferredComponentsTempDirectory}/app/src/main/AndroidManifest.xml\n'), true);

    final File manifestOutput = env.projectDir
      .childDirectory('build')
      .childDirectory(DeferredComponentsValidator.kDeferredComponentsTempDirectory)
      .childDirectory('app')
      .childDirectory('src')
      .childDirectory('main')
      .childFile('AndroidManifest.xml');
    expect(manifestOutput.existsSync(), true);
    expect(manifestOutput.readAsStringSync().contains('<meta-data android:name="io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager.loadingUnitMapping" android:value="3:component1,2:component2,4:component2"/>'), true);
    expect(manifestOutput.readAsStringSync().contains('<!-- Don\'t delete the meta-data below.'), true);
  });

  // Tests if all of the regexp whitespace detection is working.
  testWithoutContext('androidStringMapping handles whitespace within entry', () async {
    final DeferredComponentsGenSnapshotValidator validator = DeferredComponentsGenSnapshotValidator(
      env,
      exitOnFail: false,
      title: 'test check',
    );
    final Directory baseModuleDir = env.projectDir.childDirectory('android').childDirectory('app');
    final File manifest = baseModuleDir.childDirectory('src').childDirectory('main').childFile('AndroidManifest.xml');
    if (manifest.existsSync()) {
      manifest.deleteSync();
    }
    manifest.createSync(recursive: true);
    manifest.writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.splitaot">
    <application
        android:name="io.flutter.app.FlutterPlayStoreSplitApplication"
        android:label="splitaot"
        android:extractNativeLibs="false">
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:windowSoftInputMode="adjustResize">
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
        <meta-data

            android:name  = "io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager.loadingUnitMapping"

                android:value =         "invalidmapping"

            />
    </application>
</manifest>
''', flush: true, mode: FileMode.append);
    validator.checkAppAndroidManifestComponentLoadingUnitMapping(
      <DeferredComponent>[
        DeferredComponent(name: 'component1', libraries: <String>['lib2']),
        DeferredComponent(name: 'component2', libraries: <String>['lib1', 'lib4']),
      ],
      <LoadingUnit>[
        LoadingUnit(id: 2, libraries: <String>['lib1']),
        LoadingUnit(id: 3, libraries: <String>['lib2', 'lib3']),
        LoadingUnit(id: 4, libraries: <String>['lib4', 'lib5']),
      ],
    );
    validator.displayResults();
    validator.attemptToolExit();

    expect(logger.statusText.contains('Modified android files:\n'), true);
    expect(logger.statusText.contains('build/${DeferredComponentsValidator.kDeferredComponentsTempDirectory}/app/src/main/AndroidManifest.xml\n'), true);

    final File manifestOutput = env.projectDir
      .childDirectory('build')
      .childDirectory(DeferredComponentsValidator.kDeferredComponentsTempDirectory)
      .childDirectory('app')
      .childDirectory('src')
      .childDirectory('main')
      .childFile('AndroidManifest.xml');
    expect(manifestOutput.existsSync(), true);
    expect(manifestOutput.readAsStringSync().contains('<meta-data android:name="io.flutter.embedding.engine.deferredcomponents.DeferredComponentManager.loadingUnitMapping" android:value="3:component1,2:component2,4:component2"/>'), true);
    expect(manifestOutput.readAsStringSync().contains(RegExp(r'android:value[\s\n]*=[\s\n]*"invalidmapping"')), false);
    expect(manifestOutput.readAsStringSync().contains('<!-- Don\'t delete the meta-data below.'), true);
  });
}
