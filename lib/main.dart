import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/clovara_theme.dart';
import 'providers/quote_provider.dart';
import 'providers/pet_provider.dart';
import 'providers/policy_provider.dart';
import 'models/checkout_state.dart';
import 'services/firebase_service.dart';
import 'services/user_session_service.dart';
import 'services/stripe_service.dart';
import 'services/marketing_attribution_service.dart';
import 'package:flutter/foundation.dart'
  show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'config/emulator_config.dart';
import 'router/app_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web: use path URLs (no #) for SPA routes.
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Initialize Firebase (best-effort).
  // Some environments block Google's CDN (gstatic), which can prevent Firebase
  // web plugins from loading and cause a blank screen.
  // You can force-disable Firebase for local marketing/dev with:
  //   flutter run -d chrome --dart-define=DISABLE_FIREBASE=true
  final disableFirebase = const bool.fromEnvironment('DISABLE_FIREBASE', defaultValue: false);
  var firebaseReady = false;
  if (!disableFirebase) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      firebaseReady = true;
    } catch (e) {
      // Keep the app running (marketing pages, etc.). Firebase-dependent flows
      // will not work until network access is restored.
      debugPrint('⚠️ Firebase init failed (continuing without Firebase): $e');
      firebaseReady = false;
    }
  }

  // Optional: connect to local Firebase emulators when enabled.
  // Enable with: --dart-define=USE_FIREBASE_EMULATORS=true
  if (firebaseReady) {
    await EmulatorConfig.configureFirebaseEmulators();
  }

  // Initialize Stripe only where `flutter_stripe` is supported.
  // macOS builds don't have a Stripe plugin implementation.
  final supportsStripe = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  if (supportsStripe) {
    await StripeService.init();
  }

  // Setup auth state listener to handle pending quote migration on sign-in
  if (firebaseReady) {
    UserSessionService().setupAuthStateListener();
  }

  // Best-effort: start attribution session early (captures web UTMs/referrer).
  // Do not block app startup on this network call.
  MarketingAttributionService().ensureSessionStarted();

  runApp(const PetUnderwriterAI());
}

class PetUnderwriterAI extends StatelessWidget {
  const PetUnderwriterAI({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final router = createAppRouter();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuoteProvider()),
        ChangeNotifierProvider(
          create: (_) => PetProvider(firebaseService: firebaseService),
        ),
        ChangeNotifierProvider(
          create: (_) => PolicyProvider(firebaseService: firebaseService),
        ),
        ChangeNotifierProvider(create: (_) => CheckoutProvider()),
      ],
      child: MaterialApp.router(
        title: 'Clovara',
        debugShowCheckedModeBanner: false,
        theme: ClovaraTheme.light,
        darkTheme: ClovaraTheme.dark,
        themeMode: ThemeMode.light,
        // go_router integration
        routerConfig: router,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
