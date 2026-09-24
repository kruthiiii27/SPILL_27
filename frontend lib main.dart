import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


// ============================================================
// API CONFIGURATION
// ============================================================

// Android Emulator:
const String baseUrl = 'http://10.0.2.2:5000';

// Physical Android phone:
// Change to your PC's IP address, for example:
// const String baseUrl = 'http://192.168.1.10:5000';


class Api {

  static String? token;


  static Map<String, String> get headers {

    return {

      'Content-Type':
          'application/json',

      if (token != null)

        'Authorization':
            'Bearer $token'
    };
  }


  static Future<void> loadToken() async {

    final prefs =
        await SharedPreferences.getInstance();

    token =
        prefs.getString('token');
  }


  static Future<void> saveToken(
      String value) async {

    token = value;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
        'token',
        value);
  }


  static Future<void> logout() async {

    token = null;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove('token');
  }


  static Future<http.Response> get(
      String path) {

    return http.get(

      Uri.parse(
          '$baseUrl$path'),

      headers:
          headers
    );
  }


  static Future<http.Response> post(
      String path,
      Map<String, dynamic> body) {

    return http.post(

      Uri.parse(
          '$baseUrl$path'),

      headers:
          headers,

      body:
          jsonEncode(body)
    );
  }
}


// ============================================================
// APP
// ============================================================

void main() {

  runApp(
    const SpillApp()
  );
}


class SpillApp extends StatefulWidget {

  const SpillApp({
    super.key
  });


  @override
  State<SpillApp> createState() =>
      _SpillAppState();
}


class _SpillAppState
    extends State<SpillApp> {

  bool ready = false;


  @override
  void initState() {

    super.initState();

    Api.loadToken().then(
      (_) {

        setState(
          () {

            ready = true;
          }
        );
      }
    );
  }


  @override
  Widget build(
      BuildContext context) {

    if (!ready) {

      return const MaterialApp(

        home: Scaffold(

          body:
              Center(
                child:
                    CircularProgressIndicator()
              )
        )
      );
    }


    return MaterialApp(

      debugShowCheckedModeBanner:
          false,

      title:
          'SPILL',

      theme:
          ThemeData(

        useMaterial3:
            true,

        colorSchemeSeed:
            const Color(
              0xFF7B4BFF
            ),

        scaffoldBackgroundColor:
            const Color(
              0xFFF8F7FC
            ),

        inputDecorationTheme:
            const InputDecorationTheme(

          border:
              OutlineInputBorder(

            borderRadius:
                BorderRadius.all(
              Radius.circular(
                16
              )
            )
          )
        )
      ),

      home:

          Api.token == null

              ? const LoginPage()

              : const HomePage()
    );
  }
}


// ============================================================
// LOGIN / REGISTER
// ============================================================

class LoginPage
    extends StatefulWidget {

  const LoginPage({
    super.key
  });


  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}


class _LoginPageState
    extends State<LoginPage> {

  final login =
      TextEditingController(
        text:
            'demo@spill.local'
      );

  final password =
      TextEditingController(
        text:
            'demo123'
      );

  final username =
      TextEditingController();

  final email =
      TextEditingController();


  bool registerMode = false;

  bool loading = false;


  Future<void> submit() async {

    setState(
      () {
        loading = true;
      }
    );


    try {

      final response =
          await Api.post(

        registerMode

            ? '/api/register'

            : '/api/login',

        registerMode

            ? {

                'username':
                    username.text,

                'email':
                    email.text,

                'password':
                    password.text

              }

            : {

                'login':
                    login.text,

                'password':
                    password.text

              }
      );


      final data =
          jsonDecode(
              response.body);


      if (
        response.statusCode >= 200 &&
        response.statusCode < 300
      ) {

        await Api.saveToken(
          data['token']
        );


        if (mounted) {

          Navigator.pushReplacement(

            context,

            MaterialPageRoute(
              builder:
                  (_) =>
                      const HomePage()
            )
          );
        }

      } else {

        message(
          data['error'] ??
              'Request failed'
        );
      }

    } catch (e) {

      message(
        'Cannot connect to Flask server.\n$e'
      );

    } finally {

      if (mounted) {

        setState(
          () {
            loading = false;
          }
        );
      }
    }
  }


  void message(String text) {

    if (!mounted) return;

    ScaffoldMessenger.of(
        context
    ).showSnackBar(

      SnackBar(
        content:
            Text(text)
      )
    );
  }


  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      body:
          SafeArea(

        child:
            Center(

          child:
              SingleChildScrollView(

            padding:
                const EdgeInsets.all(
                  28
                ),

            child:
                Column(

              children: [

                const Text(

                  'SPILL ☕',

                  style:
                      TextStyle(

                    fontSize:
                        42,

                    fontWeight:
                        FontWeight.w900
                  )
                ),


                const SizedBox(
                  height:
                      8
                ),


                const Text(

                  'Your campus. Your stories. No names attached.',

                  textAlign:
                      TextAlign.center
                ),


                const SizedBox(
                  height:
                      36
                ),


                if (registerMode) ...[

                  TextField(

                    controller:
                        username,

                    decoration:
                        const InputDecoration(

                      labelText:
                          'Username'
                    )
                  ),


                  const SizedBox(
                    height:
                        12
                  ),


                  TextField(

                    controller:
                        email,

                    decoration:
                        const InputDecoration(

                      labelText:
                          'Email'
                    )
                  )

                ] else

                  TextField(

                    controller:
                        login,

                    decoration:
                        const InputDecoration(

                      labelText:
                          'Email or username'
                    )
                  ),


                const SizedBox(
                  height:
                      12
                ),


                TextField(

                  controller:
                      password,

                  obscureText:
                      true,

                  decoration:
                      const InputDecoration(

                    labelText:
                        'Password'
                  )
                ),


                const SizedBox(
                  height:
                      20
                ),


                FilledButton(

                  onPressed:
                      loading
                          ? null
                          : submit,

                  style:
                      FilledButton.styleFrom(

                    minimumSize:
                        const Size(
                      double.infinity,
                      52
                    )
                  ),

                  child:

                      Text(

                    loading

                        ? 'Please wait...'

                        : registerMode

                            ? 'CREATE ACCOUNT'

                            : 'LOGIN'
                  )
                ),


                TextButton(

                  onPressed:
                      () {

                    setState(
                      () {

                        registerMode =
                            !registerMode;
                      }
                    );
                  },

                  child:

                      Text(

                    registerMode

                        ? 'Already have an account? Login'

                        : 'Create an account'
                  )
                ),


                const SizedBox(
                  height:
                      18
                ),


                const Text(

                  'Demo account: demo@spill.local / demo123'
                )
              ]
            )
          )
        )
      )
    );
  }
}


// ============================================================
// HOME
// ============================================================

class HomePage
    extends StatefulWidget {

  const HomePage({
    super.key
  });


  @override
  State<HomePage> createState() =>
      _HomePageState();
}


class _HomePageState
    extends State<HomePage> {

  int index = 0;


  Future<void> logout() async {

    await Api.logout();


    if (mounted) {

      Navigator.pushReplacement(

        context,

        MaterialPageRoute(
          builder:
              (_) =>
                  const LoginPage()
        )
      );
    }
  }


  @override
  Widget build(
      BuildContext context) {

    final pages = [

      const FeedPage(),

      const ExplorePage(),

      const BookmarksPage(),

      ProfilePage(
        onLogout:
            logout
      )
    ];


    return Scaffold(

      body:
          pages[index],


      floatingActionButton:

          FloatingActionButton.extended(

        onPressed:
            () async {

          final result =
              await Navigator.push(

            context,

            MaterialPageRoute(

              builder:
                  (_) =>
                      const CreateSpillPage()
            )
          );


          if (result == true) {

            setState(
              () {}
            );
          }
        },


        icon:
            const Icon(
              Icons.add
            ),

        label:
            const Text(
              'Spill'
            )
      ),


      bottomNavigationBar:

          NavigationBar(

        selectedIndex:
            index,

        onDestinationSelected:
            (i) {

          setState(
            () {

              index = i;
            }
          );
        },


        destinations: const [

          NavigationDestination(

            icon:
                Icon(
              Icons.home_outlined
            ),

            selectedIcon:
                Icon(
              Icons.home
            ),

            label:
                'Home'
          ),


          NavigationDestination(

            icon:
                Icon(
              Icons.explore_outlined
            ),

            selectedIcon:
                Icon(
              Icons.explore
            ),

            label:
                'Explore'
          ),


          NavigationDestination(

            icon:
                Icon(
              Icons.bookmark_border
            ),

            selectedIcon:
                Icon(
              Icons.bookmark
            ),

            label:
                'Saved'
          ),


          NavigationDestination(

            icon:
                Icon(
              Icons.person_outline
            ),

            selectedIcon:
                Icon(
              Icons.person
            ),

            label:
                'Profile'
          )
        ]
      )
    );
  }
}


// ============================================================
// FEED
// ============================================================

class FeedPage
    extends StatefulWidget {

  const FeedPage({
    super.key
  });


  @override
  State<FeedPage> createState() =>
      _FeedPageState();
}


class _FeedPageState
    extends State<FeedPage> {

  List posts = [];

  bool loading = true;


  @override
  void initState() {

    super.initState();

    load();
  }


  Future<void> load() async {

    try {

      final response =
          await Api.get(
            '/api/posts'
          );


      if (
          response.statusCode == 200
      ) {

        posts =
            jsonDecode(
                response.body
            );
      }

    } finally {

      if (mounted) {

        setState(
          () {
            loading = false;
          }
        );
      }
    }
  }


  Future<void> like(
      Map post) async {

    final response =
        await Api.post(

      '/api/posts/${post['id']}/like',

      {}
    );


    if (
        response.statusCode == 200
    ) {

      load();
    }
  }


  Future<void> bookmark(
      Map post) async {

    final response =
        await Api.post(

      '/api/posts/${post['id']}/bookmark',

      {}
    );


    if (
        response.statusCode == 200
    ) {

      load();
    }
  }


  @override
  Widget build(
      BuildContext context) {

    return RefreshIndicator(

      onRefresh:
          load,

      child:
          CustomScrollView(

        slivers: [

          SliverAppBar.large(

            title:
                const Text(
              'SPILL ☕'
            ),

            actions: [

              IconButton(

                onPressed:
                    load,

                icon:
                    const Icon(
                  Icons.refresh
                )
              )
            ]
          ),


          SliverToBoxAdapter(

            child:

                Padding(

              padding:
                  const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                14
              ),

              child:
                  Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  const Text(

                    'Tea of the Day 🔥',

                    style:
                        TextStyle(

                      fontSize:
                          22,

                      fontWeight:
                          FontWeight.bold
                    )
                  ),


                  const SizedBox(
                    height:
                        4
                  ),


                  Text(

                    'Anonymous campus stories & conversations',

                    style:
                        TextStyle(

                      color:
                          Colors.grey.shade700
                    )
                  )
                ]
              )
            )
          ),


          if (loading)

            const SliverFillRemaining(

              child:
                  Center(

                child:
                    CircularProgressIndicator()
              )
            )

          else if (posts.isEmpty)

            const SliverFillRemaining(

              child:
                  Center(

                child:
                    Text(
                  'No spills yet. Be the first!'
                )
              )
            )

          else

            SliverList.builder(

              itemCount:
                  posts.length,

              itemBuilder:
                  (_, i) {

                return PostCard(

                  post:
                      posts[i],

                  onLike:
                      () => like(
                        posts[i]
                      ),

                  onBookmark:
                      () => bookmark(
                        posts[i]
                      )
                );
              }
            )
        ]
      )
    );
  }
}


// ============================================================
// POST CARD
// ============================================================

class PostCard
    extends StatelessWidget {

  final Map post;

  final VoidCallback onLike;

  final VoidCallback onBookmark;


  const PostCard({

    super.key,

    required this.post,

    required this.onLike,

    required this.onBookmark
  });


  @override
  Widget build(
      BuildContext context) {

    return Card(

      margin:
          const EdgeInsets.fromLTRB(
        16,
        6,
        16,
        10
      ),

      child:
          Padding(

        padding:
            const EdgeInsets.all(
          16
        ),

        child:
            Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Row(

              children: [

                const CircleAvatar(

                  child:
                      Text(
                    '☕'
                  )
                ),


                const SizedBox(
                  width:
                      10
                ),


                Expanded(

                  child:
                      Text(

                    'Anonymous • ${post['category']}',

                    style:
                        const TextStyle(

                      fontWeight:
                          FontWeight.bold
                    )
                  )
                ),


                PopupMenuButton(

                  itemBuilder:
                      (_) => [

                    PopupMenuItem(

                      child:
                          const Text(
                        'Report'
                      ),

                      onTap:

                          () =>

                              Future.delayed(

                                Duration.zero,

                                () => report(
                                  context,
                                  post
                                )
                              )
                    )
                  ]
                )
              ]
            ),


            const SizedBox(
              height:
                  14
            ),


            Text(

              post['content'],

              style:
                  const TextStyle(

                fontSize:
                    16,

                height:
                    1.45
              )
            ),


            const SizedBox(
              height:
                  14
            ),


            Row(

              children: [

                IconButton(

                  onPressed:
                      onLike,

                  icon:

                      Icon(

                    post['liked'] == true

                        ? Icons.favorite

                        : Icons.favorite_border
                  )
                ),


                Text(
                  '${post['likes']}'
                ),


                IconButton(

                  onPressed:

                      () {

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder:
                            (_) =>
                                CommentsPage(

                          postId:
                              post['id']
                        )
                      )
                    );
                  },

                  icon:
                      const Icon(
                    Icons.comment_outlined
                  )
                ),


                Text(
                  '${post['comments']}'
                ),


                const Spacer(),


                IconButton(

                  onPressed:
                      onBookmark,

                  icon:

                      Icon(

                    post['bookmarked'] == true

                        ? Icons.bookmark

                        : Icons.bookmark_border
                  )
                )
              ]
            )
          ]
        )
      )
    );
  }


  static Future<void> report(
      BuildContext context,
      Map post) async {

    String reason =
        'Harassment';

    final details =
        TextEditingController();


    await showDialog(

      context:
          context,

      builder:
          (_) =>

              AlertDialog(

        title:
            const Text(
          'Report Spill'
        ),


        content:

            StatefulBuilder(

          builder:
              (context, setState) {

            return Column(

              mainAxisSize:
                  MainAxisSize.min,

              children: [

                DropdownButtonFormField<String>(

                  value:
                      reason,

                  items:

                      [

                    'Harassment',

                    'Threat',

                    'Personal information',

                    'Sexual content',

                    'Misinformation',

                    'Other'

                  ]

                          .map(

                            (x) =>

                                DropdownMenuItem(

                              value:
                                  x,

                              child:
                                  Text(x)
                            )
                          )

                          .toList(),

                  onChanged:

                      (x) {

                    setState(
                      () {

                        reason =
                            x ??
                                reason;
                      }
                    );
                  }
                ),


                const SizedBox(
                  height:
                      12
                ),


                TextField(

                  controller:
                      details,

                  maxLines:
                      3,

                  decoration:
                      const InputDecoration(

                    labelText:
                        'Details'
                  )
                )
              ]
            );
          }
        ),


        actions: [

          TextButton(

            onPressed:
                () =>
                    Navigator.pop(
                      context
                    ),

            child:
                const Text(
              'Cancel'
            )
          ),


          FilledButton(

            onPressed:
                () async {

              final response =
                  await Api.post(

                '/api/posts/${post['id']}/report',

                {

                  'reason':
                      reason,

                  'details':
                      details.text
                }
              );


              if (context.mounted) {

                Navigator.pop(
                    context
                );


                ScaffoldMessenger.of(
                    context
                ).showSnackBar(

                  SnackBar(

                    content:

                        Text(

                      response.statusCode ==
                              201

                          ? 'Report submitted'

                          : 'Could not report'
                    )
                  )
                );
              }
            },

            child:
                const Text(
              'Report'
            )
          )
        ]
      )
    );
  }
}


// ============================================================
// CREATE SPILL
// ============================================================

class CreateSpillPage
    extends StatefulWidget {

  const CreateSpillPage({
    super.key
  });


  @override
  State<CreateSpillPage> createState() =>
      _CreateSpillPageState();
}


class _CreateSpillPageState
    extends State<CreateSpillPage> {

  final controller =
      TextEditingController();


  String category =
      'Campus';


  bool sending = false;


  Future<void> submit() async {

    setState(
      () {
        sending = true;
      }
    );


    try {

      final response =
          await Api.post(

        '/api/posts',

        {

          'content':
              controller.text,

          'category':
              category
        }
      );


      final data =
          jsonDecode(
              response.body
          );


      if (!mounted) return;


      if (
          response.statusCode == 201
      ) {

        final action =
            data['action'];


        showDialog(

          context:
              context,

          builder:
              (_) =>

                  AlertDialog(

            title:

                Text(

              action == 'allow'

                  ? 'Spill Published ☕'

                  : 'Sent for Review ⚠️'
            ),


            content:
                Text(
              data['message']
            ),


            actions: [

              TextButton(

                onPressed:
                    () =>
                        Navigator.pop(
                          context
                        ),

                child:
                    const Text(
                  'OK'
                )
              )
            ]
          )

        ).then(

          (_) =>
              Navigator.pop(
                context,
                true
              )
        );

      } else {

        ScaffoldMessenger.of(
            context
        ).showSnackBar(

          SnackBar(

            content:

                Text(

              data['message'] ??
                  data['error'] ??
                  'Blocked'
            )
          )
        );
      }

    } finally {

      if (mounted) {

        setState(
          () {
            sending = false;
          }
        );
      }
    }
  }


  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      appBar:
          AppBar(

        title:
            const Text(
          'Create Spill'
        )
      ),


      body:

          ListView(

        padding:
            const EdgeInsets.all(
          20
        ),

        children: [

          const Text(

            'Choose Category',

            style:
                TextStyle(

              fontWeight:
                  FontWeight.bold,

              fontSize:
                  18
            )
          ),


          const SizedBox(
            height:
                10
          ),


          DropdownButtonFormField<String>(

            value:
                category,

            items:

                [

              'Campus',

              'Relationships',

              'Confession',

              'Funny',

              'Advice',

              'Academics',

              'Other'

            ]

                    .map(

                      (x) =>

                          DropdownMenuItem(

                        value:
                            x,

                        child:
                            Text(x)
                      )
                    )

                    .toList(),

            onChanged:

                (x) {

              setState(
                () {

                  category =
                      x ??
                          category;
                }
              );
            }
          ),


          const SizedBox(
            height:
                20
          ),


          TextField(

            controller:
                controller,

            maxLines:
                10,

            maxLength:
                1000,

            decoration:
                const InputDecoration(

              labelText:
                  "What's on your mind?",

              hintText:
                  'Type your anonymous spill here...'
            )
          ),


          const SizedBox(
            height:
                16
          ),


          FilledButton.icon(

            onPressed:
                sending
                    ? null
                    : submit,

            icon:
                const Icon(
              Icons.send
            ),

            label:

                Text(

              sending

                  ? 'Checking...'

                  : 'POST ANONYMOUSLY'
            ),

            style:

                FilledButton.styleFrom(

              minimumSize:
                  const Size(
                double.infinity,
                52
              )
            )
          ),


          const SizedBox(
            height:
                12
          ),


          const Text(

            'SPILL uses server-side AI-assisted moderation before publication.',

            textAlign:
                TextAlign.center
          )
        ]
      )
    );
  }
}


// ============================================================
// COMMENTS
// ============================================================

class CommentsPage
    extends StatefulWidget {

  final int postId;


  const CommentsPage({

    super.key,

    required this.postId
  });


  @override
  State<CommentsPage> createState() =>
      _CommentsPageState();
}


class _CommentsPageState
    extends State<CommentsPage> {

  List comments = [];


  final controller =
      TextEditingController();


  @override
  void initState() {

    super.initState();

    load();
  }


  Future<void> load() async {

    final response =
        await Api.get(

      '/api/posts/${widget.postId}/comments'
    );


    if (
        response.statusCode == 200
        && mounted
    ) {

      setState(
        () {

          comments =
              jsonDecode(
                  response.body
              );
        }
      );
    }
  }


  Future<void> add() async {

    if (
        controller.text
            .trim()
            .isEmpty
    ) {

      return;
    }


    final response =
        await Api.post(

      '/api/posts/${widget.postId}/comments',

      {

        'content':
            controller.text.trim()
      }
    );


    if (
        response.statusCode == 201
    ) {

      controller.clear();

      load();

    } else {

      final data =
          jsonDecode(
              response.body
          );


      if (mounted) {

        ScaffoldMessenger.of(
            context
        ).showSnackBar(

          SnackBar(

            content:

                Text(

              data['error'] ??
                  'Blocked'
            )
          )
        );
      }
    }
  }


  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      appBar:
          AppBar(

        title:
            const Text(
          'Comments'
        )
      ),


      body:

          Column(

        children: [

          Expanded(

            child:

                ListView.builder(

              itemCount:
                  comments.length,

              itemBuilder:
                  (_, i) {

                return ListTile(

                  leading:
                      const CircleAvatar(

                    child:
                        Text(
                      '☕'
                    )
                  ),

                  title:
                      const Text(
                    'Anonymous'
                  ),

                  subtitle:

                      Text(
                    comments[i]['content']
                  )
                );
              }
            )
          ),


          Padding(

            padding:
                const EdgeInsets.all(
              12
            ),

            child:
                Row(

              children: [

                Expanded(

                  child:

                      TextField(

                    controller:
                        controller,

                    decoration:
                        const InputDecoration(

                      hintText:
                          'Add a comment...'
                    )
                  )
                ),


                IconButton(

                  onPressed:
                      add,

                  icon:
                      const Icon(
                    Icons.send
                  )
                )
              ]
            )
          )
        ]
      )
    );
  }
}


// ============================================================
// EXPLORE
// ============================================================

class ExplorePage
    extends StatelessWidget {

  const ExplorePage({
    super.key
  });


  @override
  Widget build(
      BuildContext context) {

    final categories = [

      'Campus',

      'Relationships',

      'Confession',

      'Funny',

      'Advice',

      'Academics'
    ];


    return Scaffold(

      appBar:
          AppBar(

        title:
            const Text(
          'Explore'
        )
      ),


      body:

          ListView(

        padding:
            const EdgeInsets.all(
          20
        ),

        children: [

          TextField(

            decoration:
                InputDecoration(

              hintText:
                  'Search spills...',

              prefixIcon:
                  const Icon(
                Icons.search
              ),

              filled:
                  true,

              fillColor:
                  Colors.white
            )
          ),


          const SizedBox(
            height:
                25
          ),


          const Text(

            'Categories',

            style:
                TextStyle(

              fontSize:
                  22,

              fontWeight:
                  FontWeight.bold
            )
          ),


          const SizedBox(
            height:
                12
          ),


          Wrap(

            spacing:
                10,

            runSpacing:
                10,

            children:

                categories

                    .map(

                      (x) =>

                          ActionChip(

                        avatar:

                            const Icon(

                          Icons.local_fire_department,

                          size:
                              18
                        ),

                        label:
                            Text(x),

                        onPressed:
                            () {}
                      )
                    )

                    .toList()
          )
        ]
      )
    );
  }
}


// ============================================================
// BOOKMARKS
// ============================================================

class BookmarksPage
    extends StatefulWidget {

  const BookmarksPage({
    super.key
  });


  @override
  State<BookmarksPage> createState() =>
      _BookmarksPageState();
}


class _BookmarksPageState
    extends State<BookmarksPage> {

  List posts = [];


  @override
  void initState() {

    super.initState();

    load();
  }


  Future<void> load() async {

    final response =
        await Api.get(
          '/api/bookmarks'
        );


    if (
        response.statusCode == 200
        && mounted
    ) {

      setState(
        () {

          posts =
              jsonDecode(
                  response.body
              );
        }
      );
    }
  }


  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      appBar:
          AppBar(

        title:
            const Text(
          'Saved Spills'
        )
      ),


      body:

          posts.isEmpty

              ? const Center(

                  child:
                      Text(
                    'No saved spills yet.'
                  )
                )

              : ListView(

                  children:

                      posts

                          .map(

                            (post) =>

                                PostCard(

                              post:
                                  post,

                              onLike:
                                  () {},

                              onBookmark:
                                  load
                            )
                          )

                          .toList()
                )
    );
  }
}


// ============================================================
// PROFILE
// ============================================================

class ProfilePage
    extends StatefulWidget {

  final VoidCallback onLogout;


  const ProfilePage({

    super.key,

    required this.onLogout
  });


  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}


class _ProfilePageState
    extends State<ProfilePage> {

  Map data = {};


  @override
  void initState() {

    super.initState();

    load();
  }


  Future<void> load() async {

    final response =
        await Api.get(
          '/api/me'
        );


    if (
        response.statusCode == 200
        && mounted
    ) {

      setState(
        () {

          data =
              jsonDecode(
                  response.body
              );
        }
      );
    }
  }


  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      appBar:
          AppBar(

        title:
            const Text(
          'Profile'
        )
      ),


      body:

          ListView(

        padding:
            const EdgeInsets.all(
          20
        ),

        children: [

          const CircleAvatar(

            radius:
                44,

            child:

                Text(

              '☕',

              style:
                  TextStyle(
                fontSize:
                    30
              )
            )
          ),


          const SizedBox(
            height:
                12
          ),


          Center(

            child:

                Text(

              data['username'] ??
                  '',

              style:
                  const TextStyle(

                fontSize:
                    22,

                fontWeight:
                    FontWeight.bold
              )
            )
          ),


          const SizedBox(
            height:
                25
          ),


          const ListTile(

            leading:
                Icon(
              Icons.visibility_off
            ),

            title:
                Text(
              'Public identity'
            ),

            subtitle:
                Text(
              'Hidden on posts and comments'
            )
          ),


          const ListTile(

            leading:
                Icon(
              Icons.shield_outlined
            ),

            title:
                Text(
              'Community safety'
            ),

            subtitle:
                Text(
              'AI-assisted moderation is enabled'
            )
          ),


          if (
              data['is_admin'] == true
          )

            ListTile(

              leading:

                  const Icon(

                Icons.admin_panel_settings
              ),

              title:

                  const Text(

                'Admin Dashboard'
              ),

              onTap:

                  () {

                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder:
                        (_) =>
                            const AdminPage()
                  )
                );
              }
            ),


          const SizedBox(
            height:
                20
          ),


          OutlinedButton.icon(

            onPressed:
                widget.onLogout,

            icon:
                const Icon(
              Icons.logout
            ),

            label:
                const Text(
              'Logout'
            )
          )
        ]
      )
    );
  }
}


// ============================================================
// ADMIN
// ============================================================

class AdminPage
    extends StatefulWidget {

  const AdminPage({
    super.key
  });


  @override
  State<AdminPage> createState() =>
      _AdminPageState();
}


class _AdminPageState
    extends State<AdminPage> {

  Map stats = {};

  List reports = [];


  @override
  void initState() {

    super.initState();

    load();
  }


  Future<void> load() async {

    final statsResponse =
        await Api.get(
          '/api/admin/stats'
        );


    final reportsResponse =
        await Api.get(
          '/api/admin/reports'
        );


    if (mounted) {

      setState(
        () {

          if (
              statsResponse.statusCode == 200
          ) {

            stats =
                jsonDecode(
                    statsResponse.body
                );
          }


          if (
              reportsResponse.statusCode == 200
          ) {

            reports =
                jsonDecode(
                    reportsResponse.body
                );
          }
        }
      );
    }
  }


  Future<void> action(
      int id,
      String action) async {

    await Api.post(

      '/api/admin/reports/$id/action',

      {
        'action':
            action
      }
    );


    load();
  }


  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      appBar:
          AppBar(

        title:
            const Text(
          'SPILL Admin'
        )
      ),


      body:

          RefreshIndicator(

        onRefresh:
            load,

        child:

            ListView(

          padding:
              const EdgeInsets.all(
            16
          ),

          children: [

            Row(

              children: [

                stat(
                  'Users',
                  stats['users']
                ),

                stat(
                  'Posts',
                  stats['posts']
                ),

                stat(
                  'Reports',
                  stats['reports']
                )
              ]
            ),


            const SizedBox(
              height:
                  24
            ),


            const Text(

              'Pending Reports',

              style:
                  TextStyle(

                fontSize:
                    22,

                fontWeight:
                    FontWeight.bold
              )
            ),


            const SizedBox(
              height:
                  10
            ),


            if (
                reports.isEmpty
            )

              const Text(
                'No pending reports.'
              ),


            ...reports.map(

              (report) =>

                  Card(

                child:

                    Padding(

                  padding:
                      const EdgeInsets.all(
                    14
                  ),

                  child:

                      Column(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Text(

                        'Report #${report['id']} • ${report['reason']}',

                        style:
                            const TextStyle(

                          fontWeight:
                              FontWeight.bold
                        )
                      ),


                      const SizedBox(
                        height:
                            8
                      ),


                      Text(
                        report['content']
                      ),


                      const SizedBox(
                        height:
                            12
                      ),


                      Wrap(

                        spacing:
                            8,

                        children: [

                          FilledButton(

                            onPressed:

                                () => action(

                              report['id'],

                              'remove'
                            ),

                            child:
                                const Text(
                              'Remove'
                            )
                          ),


                          OutlinedButton(

                            onPressed:

                                () => action(

                              report['id'],

                              'approve'
                            ),

                            child:
                                const Text(
                              'Approve'
                            )
                          ),


                          TextButton(

                            onPressed:

                                () => action(

                              report['id'],

                              'dismiss'
                            ),

                            child:
                                const Text(
                              'Dismiss'
                            )
                          )
                        ]
                      )
                    ]
                  )
                )
              )
            )
          ]
        )
      )
    );
  }


  Widget stat(
      String title,
      dynamic value) {

    return Expanded(

      child:

          Card(

        child:

            Padding(

          padding:
              const EdgeInsets.all(
            12
          ),

          child:

              Column(

            children: [

              Text(

                '${value ?? 0}',

                style:
                    const TextStyle(

                  fontSize:
                      25,

                  fontWeight:
                      FontWeight.bold
                )
              ),


              Text(title)
            ]
          )
        )
      )
    );
  }
}
