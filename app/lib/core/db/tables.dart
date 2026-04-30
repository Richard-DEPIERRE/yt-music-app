import 'package:drift/drift.dart';

class Tracks extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artistName => text().nullable()();
  TextColumn get artistBrowseId => text().nullable()();
  TextColumn get albumName => text().nullable()();
  TextColumn get albumBrowseId => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  BoolColumn get isLiked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get likedAt => dateTime().nullable()();
  TextColumn get downloadStatus =>
      text().withDefault(const Constant('not_downloaded'))();
  IntColumn get downloadAttempts => integer().withDefault(const Constant(0))();
  TextColumn get lastDownloadError => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get localPath => text().nullable()();
  TextColumn get downloadedCodec => text().nullable()();
  IntColumn get downloadedBitrate => integer().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {videoId};
}

class Albums extends Table {
  TextColumn get browseId => text()();
  TextColumn get title => text()();
  TextColumn get artistName => text().nullable()();
  TextColumn get artistBrowseId => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get artworkUrl => text().nullable()();
  IntColumn get trackCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {browseId};
}

class AlbumTracks extends Table {
  TextColumn get albumBrowseId => text()();
  TextColumn get videoId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {albumBrowseId, videoId};
}

class Artists extends Table {
  TextColumn get browseId => text()();
  TextColumn get name => text()();
  BoolColumn get subscribed => boolean().withDefault(const Constant(false))();
  TextColumn get artworkUrl => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {browseId};
}

class Playlists extends Table {
  TextColumn get browseId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get ownerName => text().nullable()();
  BoolColumn get isOwn => boolean().withDefault(const Constant(true))();
  IntColumn get trackCount => integer().withDefault(const Constant(0))();
  TextColumn get artworkUrl => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {browseId};
}

class PlaylistTracks extends Table {
  TextColumn get playlistBrowseId => text()();
  TextColumn get videoId => text()();
  TextColumn get setVideoId => text()();
  IntColumn get position => integer()();
  DateTimeColumn get addedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {playlistBrowseId, setVideoId};
}

class RecentlyPlayed extends Table {
  TextColumn get videoId => text()();
  DateTimeColumn get playedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {videoId, playedAt};
}

class SyncState extends Table {
  TextColumn get key => text()();
  DateTimeColumn get lastSyncedAt => dateTime()();
  TextColumn get etag => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
