import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide DateUtils;
//import 'package:flutter/material.dart' as Material show DateUtils;
import 'package:fluttertoast/fluttertoast.dart';

import 'package:awesome_notifications/awesome_notifications.dart';

import 'package:awesome_notifications_example/routes.dart';
import 'package:awesome_notifications_example/utils/notification_util.dart';
import 'package:awesome_notifications_example/utils/media_player_central.dart';
import 'package:awesome_notifications_example/utils/firebase_utils.dart';

import 'package:awesome_notifications_example/common_widgets/led_light.dart';
import 'package:awesome_notifications_example/common_widgets/check_button.dart';
import 'package:awesome_notifications_example/common_widgets/remarkble_text.dart';
import 'package:awesome_notifications_example/common_widgets/service_control_panel.dart';
import 'package:awesome_notifications_example/common_widgets/simple_button.dart';
import 'package:awesome_notifications_example/common_widgets/text_divisor.dart';
import 'package:awesome_notifications_example/common_widgets/text_note.dart';

import 'package:numberpicker/numberpicker.dart';

class NotificationExamplesPage extends StatefulWidget {
  @override
  _NotificationExamplesPageState createState() =>
      _NotificationExamplesPageState();
}

class _NotificationExamplesPageState extends State<NotificationExamplesPage> with WidgetsBindingObserver {
  String _firebaseAppToken = '';
  //String _oneSignalToken = '';

  bool delayLEDTests = false;

  bool notificationsAllowed = false;

  String packageName = 'me.carda.awesome_notifications_example';

  Future<DateTime?> pickScheduleDate(BuildContext context, {required bool isUtc}) async {
    TimeOfDay? timeOfDay;
    DateTime now = isUtc ? DateTime.now().toUtc() : DateTime.now();
    DateTime? newDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(Duration(days: 365)));

    if (newDate != null) {
      timeOfDay = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(Duration(minutes: 1))),
      );

      if (timeOfDay != null) {
        return isUtc ?
          DateTime.utc(newDate.year, newDate.month, newDate.day, timeOfDay.hour, timeOfDay.minute) :
          DateTime(newDate.year, newDate.month, newDate.day, timeOfDay.hour, timeOfDay.minute);
      }
    }
    return null;
  }

  Future<int?> pickBadgeCounter(BuildContext context) async {
    // show the dialog
    return showDialog<int?>(
      context: context,
      builder: (BuildContext context) {
        int amount = 50;

        return AlertDialog(
          title: Text("Choose the new badge amount"),
          content: NumberPicker(
            value: amount,
            minValue: 0,
            maxValue: 999,
            onChanged: (newValue) => amount = newValue,
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(amount);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

    requestNotificationPermissions();

    // If you pretend to use the firebase service, you need to initialize it
    // getting a valid token
    FirebaseUtils.initializeFirebaseService(context).then((String firebaseAppToken){
      if (!mounted) {
        _firebaseAppToken = firebaseAppToken;
      } else {
        setState(() {
          _firebaseAppToken = firebaseAppToken;
        });
      }
    });

    AwesomeNotifications().createdStream.listen((receivedNotification) {
      String? createdSourceText =
          AssertUtils.toSimpleEnumString(receivedNotification.createdSource);
      Fluttertoast.showToast(msg: '$createdSourceText notification created');
    });

    AwesomeNotifications().displayedStream.listen((receivedNotification) {
      String? createdSourceText =
          AssertUtils.toSimpleEnumString(receivedNotification.createdSource);
      Fluttertoast.showToast(msg: '$createdSourceText notification displayed');
    });

    AwesomeNotifications().dismissedStream.listen((receivedNotification) {
      String? dismissedSourceText = AssertUtils.toSimpleEnumString(
          receivedNotification.dismissedLifeCycle);
      Fluttertoast.showToast(
          msg: 'Notification dismissed on $dismissedSourceText');
    });

    AwesomeNotifications().actionStream.listen((receivedNotification) {
      if (!StringUtils.isNullOrEmpty(receivedNotification.buttonKeyInput)) {
        processInputTextReceived(receivedNotification);
      } else if (!StringUtils.isNullOrEmpty(
              receivedNotification.buttonKeyPressed) &&
          receivedNotification.buttonKeyPressed.startsWith('MEDIA_')) {
        processMediaControls(receivedNotification);
      } else {
        processDefaultActionReceived(context, receivedNotification);
      }
    });

    // this is not part of notification system, but of the media player simulator instead
    MediaPlayerCentral.mediaStream.listen((media) {
      switch (MediaPlayerCentral.mediaLifeCycle) {
        case MediaLifeCycle.Stopped:
          cancelNotification(100);
          break;

        case MediaLifeCycle.Paused:
          updateNotificationMediaPlayer(100, media);
          break;

        case MediaLifeCycle.Playing:
          updateNotificationMediaPlayer(100, media);
          break;
      }
    });
  }

  Future<bool> requestNotificationPermissions() async {

    bool isAllowed = await requireUserNotificationPermissions(context);

    if(mounted){
      setState(() {
        notificationsAllowed = isAllowed;
      });
    } else {
      notificationsAllowed = isAllowed;
    }

    return isAllowed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state == AppLifecycleState.resumed){
      AwesomeNotifications().isNotificationAllowed().then((bool isAllowed){
        if(mounted){
          setState(() {
            notificationsAllowed = isAllowed;
          });
        } else {
          notificationsAllowed = isAllowed;
        }
      });
    }
  }

  @override
  void dispose() {
    AwesomeNotifications().dispose();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    ThemeData themeData = Theme.of(context);

    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          brightness: Brightness.light,
          title: Image.asset(
              'assets/images/awesome-notifications-logo-color.png',
              width: mediaQuery.size.width *
                  0.6), //Text('Local Notification Example App', style: TextStyle(fontSize: 20)),
          elevation: 10,
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          children: <Widget>[
            /* ******************************************************************** */

            TextDivisor(title: 'Package name'),
            RemarkableText(text: packageName, color: themeData.primaryColor),
            SimpleButton('Copy package name', onPressed: () {
              Clipboard.setData(ClipboardData(text: packageName));
            }),

            /* ******************************************************************** */

            TextDivisor(title: 'Push Service Status'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                ServiceControlPanel('Firebase',
                    !StringUtils.isNullOrEmpty(_firebaseAppToken), themeData,
                    onPressed: () => Navigator.pushNamed(
                        context, PAGE_FIREBASE_TESTS,
                        arguments: _firebaseAppToken)),
                /*
              /// TODO MISSING IMPLEMENTATION FOR ONE SIGNAL
              ServiceControlPanel(
                  'One Signal',
                  _oneSignalToken.isNotEmpty,
                  themeData
              ),
              */
              ],
            ),
            TextNote(
                'Is not necessary to use Firebase (or other) services to use local notifications. But all they can be used simultaneously.'),

            /* ******************************************************************** */

            TextDivisor(title: 'Permission to send Notifications'),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Column(
                    children: [
                      Text(notificationsAllowed ? 'Allowed' : 'Not allowed',
                          style: TextStyle(
                              color: notificationsAllowed
                                  ? Colors.green
                                  : Colors.red)),
                      LedLight(notificationsAllowed)
                    ],
                  )
                ]),
            TextNote(
                'To send local and push notifications, it is necessary to obtain the user\'s consent. Keep in mind that he user consent can be revoked at any time.\n\n'
                '* Android: notifications are enabled by default and are considered not dangerous.\n'
                '* iOS: notifications are not enabled by default and you must explicitly request it to the user.'),
            SimpleButton('Request permission',
                onPressed: () => showRequestUserPermissionDialog(context)),
            SimpleButton("Display notification's config page",
                onPressed: () => showNotificationConfigPage()),

            /* ******************************************************************** */

            TextDivisor(title: 'Basic Notifications'),
            TextNote('A simple and fast notification to fresh start.\n\n'
                'Tap on notification when it appears on your system tray to go to Details page.'),
            SimpleButton('Show the most basic notification',
                onPressed: () => showBasicNotification(context, 1)),
            SimpleButton('Show notification with payload',
                onPressed: () => showNotificationWithPayloadContent(context, 1)),
            SimpleButton('Show notification without body content',
                onPressed: () => showNotificationWithoutBody(context, 1)),
            SimpleButton('Show notification without title content',
                onPressed: () => showNotificationWithoutTitle(context, 1)),
            SimpleButton('Send background notification',
                onPressed: () => sendBackgroundNotification(context, 1)),
            SimpleButton('Cancel the basic notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(1)),

            /* ******************************************************************** */

            TextDivisor(title: 'Big Picture Notifications'),
            TextNote(
                'To show any images on notification, at any place, you need to include the respective source prefix before the path.'
                '\n\n'
                'Images can be defined using 4 prefix types:'
                '\n\n'
                '* Asset: images access through Flutter asset method.\n\t Example:\n\t asset://path/to/image-asset.png'
                '\n\n'
                '* Network: images access through internet connection.\n\t Example:\n\t http(s)://url.com/to/image-asset.png'
                '\n\n'
                '* File: images access through files stored on device.\n\t Example:\n\t file://path/to/image-asset.png'
                '\n\n'
                '* Resource: images access through drawable native resources.\n\t Example:\n\t resource://url.com/to/image-asset.png'),
            SimpleButton('Show large icon notification',
                onPressed: () => showLargeIconNotification(context, 2)),
            SimpleButton('Show big picture notification\n(Network Source)',
                onPressed: () => showBigPictureNetworkNotification(context, 2)),
            SimpleButton('Show big picture notification\n(Asset Source)',
                onPressed: () => showBigPictureAssetNotification(context, 2)),
            SimpleButton('Show big picture notification\n(File Source)',
                onPressed: () => showBigPictureFileNotification(context, 2)),
            SimpleButton('Show big picture notification\n(Resource Source)',
                onPressed: () => showBigPictureResourceNotification(context, 2)),
            SimpleButton(
                'Show big picture and\nlarge icon notification simultaneously',
                onPressed: () => showBigPictureAndLargeIconNotification(context, 2)),
            SimpleButton(
                'Show big picture notification,\n but hide large icon on expand',
                onPressed: () =>
                    showBigPictureNotificationHideExpandedLargeIcon(context, 2)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(2)),

            /* ******************************************************************** */

            TextDivisor(
                title:
                    'Emojis ${Emojis.smile_alien}${Emojis.transport_air_rocket}'),
            TextNote(
                'To send local and push notifications with emojis, use the class Emoji concatenated with your text.\n\n'
                'Attention: not all Emojis work with all platforms. Please, test the specific emoji before using it in production.'),
            SimpleButton('Show notification with emojis',
                onPressed: () => showEmojiNotification(context, 1)),
            SimpleButton(
              'Go to complete Emojis list (web)',
              onPressed: () => externalUrl(
                  'https://unicode.org/emoji/charts/full-emoji-list.html'),
            ),

            /* ******************************************************************** */

            TextDivisor(title: 'Locked Notifications (onGoing - Android)'),
            TextNote(
                'To send local or push locked notification, that users cannot dismiss it swiping it, set the "locked" property to true.\n\n' +
                    "Attention: Notification's content locked property has priority over the Channel's one."),
            SimpleButton('Send/Update the locked notification',
                onPressed: () => showLockedNotification(context, 2)),
            SimpleButton('Send/Update the unlocked notification',
                onPressed: () => showUnlockedNotification(context, 2)),

            /* ******************************************************************** */

            TextDivisor(title: 'Notification Importance (Priority)'),
            TextNote(
                'To change the importance level of notifications, please set the importance in the respective channel.\n\n'
                'The possible importance levels are the following:\n\n'
                'Max: Makes a sound and appears as a heads-up notification.\n'
                'Higher: shows everywhere, makes noise and peeks. May use full screen intents.\n'
                'Default: shows everywhere, makes noise, but does not visually intrude.\n'
                'Low: Shows in the shade, and potentially in the status bar (see shouldHideSilentStatusBarIcons()), but is not audibly intrusive\n.'
                'Min: only shows in the shade, below the fold.\n'
                'None: disable the channel\n\n'
                "Attention: Notification's channel importance can only be defined on first time."),
            SimpleButton('Display notification with NotificationImportance.Max',
                onPressed: () =>
                    showNotificationImportance(context, 3, NotificationImportance.Max)),
            SimpleButton(
                'Display notification with NotificationImportance.High',
                onPressed: () =>
                    showNotificationImportance(context, 3, NotificationImportance.High)),
            SimpleButton(
                'Display notification with NotificationImportance.Default',
                onPressed: () => showNotificationImportance(context,
                    3, NotificationImportance.Default)),
            SimpleButton('Display notification with NotificationImportance.Low',
                onPressed: () =>
                    showNotificationImportance(context, 3, NotificationImportance.Low)),
            SimpleButton('Display notification with NotificationImportance.Min',
                onPressed: () =>
                    showNotificationImportance(context, 3, NotificationImportance.Min)),
            SimpleButton(
                'Display notification with NotificationImportance.None',
                onPressed: () =>
                    showNotificationImportance(context, 3, NotificationImportance.None)),

            /* ******************************************************************** */

            TextDivisor(title: 'Action Buttons'),
            TextNote('Action buttons can be used in four types:'
                '\n\n'
                '* Default: after user taps, the notification bar is closed and an action event is fired.'
                '\n\n'
                '* InputField: after user taps, a input text field is displayed to capture input by the user.'
                '\n\n'
                '* DisabledAction: after user taps, the notification bar is closed, but the respective action event is not fired.'
                '\n\n'
                '* KeepOnTop: after user taps, the notification bar is not closed, but an action event is fired.'),
            TextNote(
                'Since Android Nougat, icons are only displayed on media layout. The icon media needs to be a native resource type.'),
            SimpleButton(
                'Show notification with\nsimple Action buttons (one disabled)',
                onPressed: () => showNotificationWithActionButtons(context, 3)),
            SimpleButton('Show notification with\nIcons and Action buttons',
                onPressed: () => showNotificationWithIconsAndActionButtons(context, 3)),
            SimpleButton('Show notification with\nReply and Action button',
                onPressed: () => showNotificationWithActionButtonsAndReply(context, 3)),
            SimpleButton('Show Big picture notification\nwith Action Buttons',
                onPressed: () => showBigPictureNotificationActionButtons(context, 3)),
            SimpleButton(
                'Show Big picture notification\nwith Reply and Action button',
                onPressed: () =>
                    showBigPictureNotificationActionButtonsAndReply(context, 3)),
            SimpleButton(
                'Show Big text notification\nwith Reply and Action button',
                onPressed: () => showBigTextNotificationWithActionAndReply(context, 3)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(3)),

            /* ******************************************************************** */

            TextDivisor(title: 'Badge Indicator'),
            TextNote(
                '"Badge" is an indicator of how many notifications (or anything else) that have not been viewed by the user (iOS and some versions of Android) '
                'or even a reminder of new things arrived (Android native).\n\n'
                'For platforms that show the global indicator over the app icon, is highly recommended to erase this annoying counter as soon '
                'as possible and even let a shortcut menu with this option outside your app, similar to "mark as read" on e-mail. The amount counter '
                'is automatically managed by this plugin for each individual installation, and incremented for every notification sent to channels '
                'with "badge" set to TRUE.\n\n'
                'OBS: Some Android distributions provide badge counter over the app icon, similar to iOS (LG, Samsung, HTC, Sony, etc) .\n\n'
                'OBS2: Android has 2 badge counters. One global and other for each channel. You can only manipulate the global counter. The channels badge are automatically'
                'managed by the system and is reset when all notifications are cleared or tapped.\n\n'
                'OBS3: Badge channels for native Android only works on version 8.0 (API level 26) and beyond.'),
            SimpleButton(
                'Shows a notification with a badge indicator channel activate',
                onPressed: () => showBadgeNotification(context, Random().nextInt(100))),
            SimpleButton(
                'Shows a notification with a badge indicator channel deactivate',
                onPressed: () =>
                    showWithoutBadgeNotification(context, Random().nextInt(100))),
            SimpleButton('Read the badge indicator count', onPressed: () async {
              int amount = await getBadgeIndicator();
              Fluttertoast.showToast(msg: 'Badge count: $amount');
            }),
            SimpleButton('Set manually the badge indicator',
                onPressed: () async {
              int? amount = await pickBadgeCounter(context);
              if (amount != null) {
                setBadgeIndicator(amount);
              }
            }),
            SimpleButton('Reset the badge indicator',
                onPressed: () => resetBadgeIndicator()),
            SimpleButton('Cancel all the badge test notifications',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelAllNotifications()),

            /* ******************************************************************** */

            TextDivisor(title: 'Vibration Patterns'),
            TextNote(
                'The PushNotification plugin has 3 vibration patters as example, but you perfectly can create your own patter.'
                '\n'
                'The patter is made by a list of big integer, separated between ON and OFF duration in milliseconds.'),
            TextNote(
                'A vibration pattern pre-configured in a channel could be updated at any time using the method PushNotification.setChannel'),
            SimpleButton('Show plain notification with low vibration pattern',
                onPressed: () => showLowVibrationNotification(context, 4)),
            SimpleButton(
                'Show plain notification with medium vibration pattern',
                onPressed: () => showMediumVibrationNotification(context, 4)),
            SimpleButton('Show plain notification with high vibration pattern',
                onPressed: () => showHighVibrationNotification(context, 4)),
            SimpleButton(
                'Show plain notification with custom vibration pattern',
                onPressed: () => showCustomVibrationNotification(context, 4)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(4)),

            /* ******************************************************************** */

            TextDivisor(title: 'Notification Channels'),
            TextNote(
                'The channel is a category identifier which notifications are pre-configured and organized before sent.'
                '\n\n'
                'On Android, since Oreo version, the notification channel is mandatory and can be managed by the user on your app config page.\n'
                'Also channels can only update his title and description. All the other parameters could only be change if you erase the channel and recreates it with a different ID.'
                'For other devices, such iOS, notification channels are emulated and used only as pre-configurations.'),
            SimpleButton('Create a test channel called "Editable channel"',
                onPressed: () => createTestChannel('Editable channel')),
            SimpleButton(
                'Update the title and description of "Editable channel"',
                onPressed: () => updateTestChannel('Editable channel')),
            SimpleButton('Remove "Editable channel"',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => removeTestChannel('Editable channel')),

            /* ******************************************************************** */

            TextDivisor(title: 'LEDs and Colors'),
            TextNote(
                'The led colors and the default layout color are independent'),
            TextNote('Some devices need to be locked to activate LED lights.'
                '\n'
                'If that is your case, please delay the notification to give to you enough time.'),
            CheckButton('Delay notifications for 5 seconds', delayLEDTests,
                onPressed: (value) {
              setState(() {
                delayLEDTests = value;
              });
            }),
            SimpleButton('Notification with red text color\nand red LED',
                onPressed: () => redNotification(context, 5, delayLEDTests)),
            SimpleButton('Notification with yellow text color\nand yellow LED',
                onPressed: () => yellowNotification(context, 5, delayLEDTests)),
            SimpleButton('Notification with green text color\nand green LED',
                onPressed: () => greenNotification(context, 5, delayLEDTests)),
            SimpleButton('Notification with blue text color\nand blue LED',
                onPressed: () => blueNotification(context, 5, delayLEDTests)),
            SimpleButton('Notification with purple text color\nand purple LED',
                onPressed: () => purpleNotification(context, 5, delayLEDTests)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(5)),

            /* ******************************************************************** */

            TextDivisor(title: 'Notification Sound'),
            SimpleButton('Show notification with custom sound',
                onPressed: () => showCustomSoundNotification(context, 6)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(6)),

            /* ******************************************************************** */

            TextDivisor(title: 'Silenced Notifications'),
            SimpleButton('Show notification with no sound',
                onPressed: () => showNotificationWithNoSound(context, 7)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(7)),

            /* ******************************************************************** */

            TextDivisor(title: 'Scheduled Notifications'),
            SimpleButton('Schedule notification with local time zone', onPressed: () async {
              DateTime? pickedDate = await pickScheduleDate(context, isUtc: false);
              if (pickedDate != null) {
                showNotificationAtScheduleCron(context, 8, pickedDate);
              }
            }),
            SimpleButton('Schedule notification with utc time zone', onPressed: () async {
              DateTime? pickedDate = await pickScheduleDate(context, isUtc: true);
              if (pickedDate != null) {
                showNotificationAtScheduleCron(context, 8, pickedDate);
              }
            }),
            SimpleButton(
              'Show notification at every single minute',
              onPressed: () => repeatMinuteNotification(context, 8),
            ),
            /*
          SimpleButton(
            'Show notification 3 times, spaced 10 seconds from each other',
            onPressed: () => repeatPreciseThreeTimes(8),
          ),
          */
            SimpleButton(
              'Show notification at every single minute o\'clock',
              onPressed: () => repeatMinuteNotificationOClock(context, 8),
            ),
            /*
          SimpleButton(
            'Show notification only on workweek days\nat 10:00 am (local)',
            onPressed: () => showScheduleAtWorkweekDay10AmLocal(8),
          ),
          */
            SimpleButton(
              'Get current time zone reference name',
              onPressed: () =>
                  getCurrentTimeZone().then((timeZone) => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                          backgroundColor: Color(0xfffbfbfb),
                          title: Center(child: Text('Current Time Zone')),
                          content: SizedBox( height: 80.0, child: Center(child: Column(
                            children: [
                              Text(DateUtils.parseDateToString(DateTime.now())!),
                              Text(timeZone),
                            ],
                          )))
                      )
                  ))
            ),
            SimpleButton(
              'Get utc time zone reference name',
              onPressed: () =>
                  getUtcTimeZone().then((timeZone) => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                          backgroundColor: Color(0xfffbfbfb),
                          title: Center(child: Text('UTC Time Zone')),
                          content: SizedBox( height: 80.0, child: Center(child: Column(
                            children: [
                              Text(DateUtils.parseDateToString(DateTime.now().toUtc())!),
                              Text(timeZone),
                            ],
                          )))
                      )
                  ))
            ),
            SimpleButton('List all active schedules',
                onPressed: () => listScheduledNotifications(context)),
            SimpleButton('Cancel the notification and its schedule',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(8)),
            SimpleButton('Dismiss the active notification without cancel its schedule',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => dismissNotification(8)),
            SimpleButton('Cancel the active schedule without dismiss the active notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelSchedule(8)),
            SimpleButton('Cancel all active schedules without dismiss the active notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: cancelAllSchedules),
            SimpleButton('Dismiss all active notifications',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: dismissAllNotifications),
            SimpleButton('Cancel All notifications and schedules',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: cancelAllNotifications),

            /* ******************************************************************** */

            TextDivisor(title: 'Get Next Schedule Date'),
            TextNote('This is a simple example to show how to query the next valid schedule date. The date components follow the ISO 8601 standard.'),
            SimpleButton('Get next Monday after date', onPressed: () async {
              DateTime? referenceDate = await pickScheduleDate(context, isUtc: false);

                NotificationSchedule schedule =
                    NotificationCalendar(weekday: DateTime.monday, hour: 0, minute: 0, second: 0);
                    //NotificationCalendar.fromDate(date: expectedDate);

                DateTime? nextValidDate = await AwesomeNotifications()
                    .getNextDate(schedule, fixedDate: referenceDate);

                late String response;
                if(nextValidDate == null)
                  response = 'There is no more valid date for this schedule';
                else
                  response = DateUtils.parseDateToString(nextValidDate.toUtc(), format: 'dd/MM/yyyy')!;


              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text("Next valid schedule"),
                  content: SizedBox(
                      height: 50,
                      child: Center(child: Text(response))
                  ),
                  actions: [
                    TextButton(
                      child: Text("OK"),
                      onPressed: () {
                        Navigator.of(context).pop(null);
                      },
                    )
                  ],
                )
              );
            }),

            /* ******************************************************************** */

            TextDivisor(title: 'Media Player'),
            TextNote(
                'The media player its just emulated and was built to help me to check if the notification media control contemplates the dev demands, such as sync state, etc.'
                '\n\n'
                'The layout itself was built just for fun, you can use it as you wish for.'
                '\n\n'
                'ATENTION: There is no media reproducing in any place, its just a Timer to pretend a time passing.'),
            SimpleButton('Show media player',
                onPressed: () =>
                    Navigator.pushNamed(context, PAGE_MEDIA_DETAILS)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(100)),

            /* ******************************************************************** */

            TextDivisor(title: 'Progress Notifications'),
            SimpleButton('Show indeterminate progress notification',
                onPressed: () => showIndeterminateProgressNotification(context, 9)),
            SimpleButton('Show progress notification - updates every second',
                onPressed: () => showProgressNotification(context, 9)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(9)),

            /* ******************************************************************** */

            TextDivisor(title: 'Inbox Notifications'),
            SimpleButton(
              'Show Inbox notification',
              onPressed: () => showInboxNotification(10),
            ),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(10)),

            /* ******************************************************************** */
            /*
            TextDivisor(title: 'Messaging Notifications'),
            SimpleButton('Show Messaging notification\n(Work in progress)',
                onPressed: null // showMessagingNotification(11)
                ),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(11)),
            */
            /* ******************************************************************** */

            TextDivisor(title: 'Grouped Notifications'),
            SimpleButton('Show grouped notifications',
                onPressed: () => showGroupedNotifications(context, 12)),
            SimpleButton('Cancel notification',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: () => cancelNotification(12)),

            /* ******************************************************************** */
            TextDivisor(),
            SimpleButton('Dismiss all notifications',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: dismissAllNotifications),
            SimpleButton('Cancel all active schedules',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: cancelAllSchedules),
            SimpleButton('Cancel all notifications and schedules',
                backgroundColor: Colors.red,
                labelColor: Colors.white,
                onPressed: cancelAllNotifications),
          ],
        ));
  }
}
