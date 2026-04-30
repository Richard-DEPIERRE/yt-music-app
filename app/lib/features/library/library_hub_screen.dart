import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LibraryHubScreen extends StatelessWidget {
  const LibraryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Liked songs'),
            onTap: () => context.push('/library/liked'),
          ),
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('Playlists'),
            onTap: () => context.push('/library/playlists'),
          ),
          ListTile(
            leading: const Icon(Icons.subscriptions),
            title: const Text('Subscriptions'),
            onTap: () => context.push('/library/subscriptions'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History'),
            onTap: () => context.push('/library/history'),
          ),
        ],
      ),
    );
  }
}
