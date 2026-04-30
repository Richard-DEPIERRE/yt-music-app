import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class TrackListTile extends StatelessWidget {
  const TrackListTile({
    required this.title,
    this.artist,
    this.artworkUrl,
    this.onTap,
    super.key,
  });

  final String title;
  final String? artist;
  final String? artworkUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: artworkUrl == null
            ? const ColoredBox(color: Colors.black26)
            : CachedNetworkImage(imageUrl: artworkUrl!, fit: BoxFit.cover),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: artist == null
          ? null
          : Text(artist!, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
