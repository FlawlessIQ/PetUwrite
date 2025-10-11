import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/petuwrite_theme.dart';
import 'auth/auth_gate.dart';
import 'screens/homepage.dart';
import 'screens/onboarding_screen.dart';
import 'screens/quote_flow_screen.dart';
import 'screens/conversational_quote_flow.dart';
import 'screens/plan_selection_screen.dart';
import 'screens/auth_required_checkout.dart';
import 'screens/policy_confirmation_screen.dart';
import 'providers/quote_provider.dart';
import 'providers/pet_provider.dart';
import 'providers/policy_provider.dart';
import 'models/checkout_state.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Stripe (will be configured with real keys later)
  // await StripeService.init();
  
  runApp(const PetUnderwriterAI());
}

class PetUnderwriterAI extends StatelessWidget {
  const PetUnderwriterAI({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuoteProvider()),
        ChangeNotifierProvider(
          create: (_) => PetProvider(firebaseService: firebaseService),
        ),
        ChangeNotifierProvider(
          create: (_) => PolicyProvider(firebaseService: firebaseService),
        ),
        ChangeNotifierProvider(
          create: (_) => CheckoutProvider(),
        ),
      ],
      child: MaterialApp(
        title: PetUwriteAssets.appName,
        debugShowCheckedModeBanner: false,
        theme: PetUwriteTheme.lightTheme,
        darkTheme: PetUwriteTheme.darkTheme,
        themeMode: ThemeMode.light,
        // Start with AuthGate - routes to homepage (unauthenticated) or dashboard (authenticated)
        home: const AuthGate(),
        routes: {
          '/home': (context) => const Homepage(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/quote': (context) => const QuoteFlowScreen(),
          '/conversational-quote': (context) => const ConversationalQuoteFlow(),
          '/plan-selection': (context) => const PlanSelectionScreen(),
          '/confirmation': (context) => const PolicyConfirmationScreen(),
          '/auth-gate': (context) => const AuthGate(),
        },
        onGenerateRoute: (settings) {
          // Handle checkout route with authentication check
          if (settings.name == '/checkout') {
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && args.containsKey('pet') && args.containsKey('selectedPlan')) {
              return MaterialPageRoute(
                builder: (context) => AuthRequiredCheckout(
                  pet: args['pet'],
                  selectedPlan: args['selectedPlan'],
                ),
              );
            }
          }
          return null;
        },
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
