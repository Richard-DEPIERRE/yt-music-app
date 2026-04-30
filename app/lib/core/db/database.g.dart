// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TracksTable extends Tracks with TableInfo<$TracksTable, Track> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistBrowseIdMeta = const VerificationMeta(
    'artistBrowseId',
  );
  @override
  late final GeneratedColumn<String> artistBrowseId = GeneratedColumn<String>(
    'artist_browse_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumNameMeta = const VerificationMeta(
    'albumName',
  );
  @override
  late final GeneratedColumn<String> albumName = GeneratedColumn<String>(
    'album_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumBrowseIdMeta = const VerificationMeta(
    'albumBrowseId',
  );
  @override
  late final GeneratedColumn<String> albumBrowseId = GeneratedColumn<String>(
    'album_browse_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLikedMeta = const VerificationMeta(
    'isLiked',
  );
  @override
  late final GeneratedColumn<bool> isLiked = GeneratedColumn<bool>(
    'is_liked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_liked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _likedAtMeta = const VerificationMeta(
    'likedAt',
  );
  @override
  late final GeneratedColumn<DateTime> likedAt = GeneratedColumn<DateTime>(
    'liked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadStatusMeta = const VerificationMeta(
    'downloadStatus',
  );
  @override
  late final GeneratedColumn<String> downloadStatus = GeneratedColumn<String>(
    'download_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_downloaded'),
  );
  static const VerificationMeta _downloadAttemptsMeta = const VerificationMeta(
    'downloadAttempts',
  );
  @override
  late final GeneratedColumn<int> downloadAttempts = GeneratedColumn<int>(
    'download_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastDownloadErrorMeta = const VerificationMeta(
    'lastDownloadError',
  );
  @override
  late final GeneratedColumn<String> lastDownloadError =
      GeneratedColumn<String>(
        'last_download_error',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedCodecMeta = const VerificationMeta(
    'downloadedCodec',
  );
  @override
  late final GeneratedColumn<String> downloadedCodec = GeneratedColumn<String>(
    'downloaded_codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedBitrateMeta = const VerificationMeta(
    'downloadedBitrate',
  );
  @override
  late final GeneratedColumn<int> downloadedBitrate = GeneratedColumn<int>(
    'downloaded_bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    videoId,
    title,
    artistName,
    artistBrowseId,
    albumName,
    albumBrowseId,
    durationMs,
    artworkUrl,
    isLiked,
    likedAt,
    downloadStatus,
    downloadAttempts,
    lastDownloadError,
    pinned,
    localPath,
    downloadedCodec,
    downloadedBitrate,
    sizeBytes,
    downloadedAt,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Track> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    }
    if (data.containsKey('artist_browse_id')) {
      context.handle(
        _artistBrowseIdMeta,
        artistBrowseId.isAcceptableOrUnknown(
          data['artist_browse_id']!,
          _artistBrowseIdMeta,
        ),
      );
    }
    if (data.containsKey('album_name')) {
      context.handle(
        _albumNameMeta,
        albumName.isAcceptableOrUnknown(data['album_name']!, _albumNameMeta),
      );
    }
    if (data.containsKey('album_browse_id')) {
      context.handle(
        _albumBrowseIdMeta,
        albumBrowseId.isAcceptableOrUnknown(
          data['album_browse_id']!,
          _albumBrowseIdMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('is_liked')) {
      context.handle(
        _isLikedMeta,
        isLiked.isAcceptableOrUnknown(data['is_liked']!, _isLikedMeta),
      );
    }
    if (data.containsKey('liked_at')) {
      context.handle(
        _likedAtMeta,
        likedAt.isAcceptableOrUnknown(data['liked_at']!, _likedAtMeta),
      );
    }
    if (data.containsKey('download_status')) {
      context.handle(
        _downloadStatusMeta,
        downloadStatus.isAcceptableOrUnknown(
          data['download_status']!,
          _downloadStatusMeta,
        ),
      );
    }
    if (data.containsKey('download_attempts')) {
      context.handle(
        _downloadAttemptsMeta,
        downloadAttempts.isAcceptableOrUnknown(
          data['download_attempts']!,
          _downloadAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('last_download_error')) {
      context.handle(
        _lastDownloadErrorMeta,
        lastDownloadError.isAcceptableOrUnknown(
          data['last_download_error']!,
          _lastDownloadErrorMeta,
        ),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('downloaded_codec')) {
      context.handle(
        _downloadedCodecMeta,
        downloadedCodec.isAcceptableOrUnknown(
          data['downloaded_codec']!,
          _downloadedCodecMeta,
        ),
      );
    }
    if (data.containsKey('downloaded_bitrate')) {
      context.handle(
        _downloadedBitrateMeta,
        downloadedBitrate.isAcceptableOrUnknown(
          data['downloaded_bitrate']!,
          _downloadedBitrateMeta,
        ),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  Track map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Track(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artistName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_name'],
      ),
      artistBrowseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_browse_id'],
      ),
      albumName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_name'],
      ),
      albumBrowseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_browse_id'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      isLiked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_liked'],
      )!,
      likedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}liked_at'],
      ),
      downloadStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_status'],
      )!,
      downloadAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_attempts'],
      )!,
      lastDownloadError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_download_error'],
      ),
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      downloadedCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}downloaded_codec'],
      ),
      downloadedBitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bitrate'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class Track extends DataClass implements Insertable<Track> {
  final String videoId;
  final String title;
  final String? artistName;
  final String? artistBrowseId;
  final String? albumName;
  final String? albumBrowseId;
  final int? durationMs;
  final String? artworkUrl;
  final bool isLiked;
  final DateTime? likedAt;
  final String downloadStatus;
  final int downloadAttempts;
  final String? lastDownloadError;
  final bool pinned;
  final String? localPath;
  final String? downloadedCodec;
  final int? downloadedBitrate;
  final int? sizeBytes;
  final DateTime? downloadedAt;
  final DateTime? lastPlayedAt;
  const Track({
    required this.videoId,
    required this.title,
    this.artistName,
    this.artistBrowseId,
    this.albumName,
    this.albumBrowseId,
    this.durationMs,
    this.artworkUrl,
    required this.isLiked,
    this.likedAt,
    required this.downloadStatus,
    required this.downloadAttempts,
    this.lastDownloadError,
    required this.pinned,
    this.localPath,
    this.downloadedCodec,
    this.downloadedBitrate,
    this.sizeBytes,
    this.downloadedAt,
    this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artistName != null) {
      map['artist_name'] = Variable<String>(artistName);
    }
    if (!nullToAbsent || artistBrowseId != null) {
      map['artist_browse_id'] = Variable<String>(artistBrowseId);
    }
    if (!nullToAbsent || albumName != null) {
      map['album_name'] = Variable<String>(albumName);
    }
    if (!nullToAbsent || albumBrowseId != null) {
      map['album_browse_id'] = Variable<String>(albumBrowseId);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    map['is_liked'] = Variable<bool>(isLiked);
    if (!nullToAbsent || likedAt != null) {
      map['liked_at'] = Variable<DateTime>(likedAt);
    }
    map['download_status'] = Variable<String>(downloadStatus);
    map['download_attempts'] = Variable<int>(downloadAttempts);
    if (!nullToAbsent || lastDownloadError != null) {
      map['last_download_error'] = Variable<String>(lastDownloadError);
    }
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || downloadedCodec != null) {
      map['downloaded_codec'] = Variable<String>(downloadedCodec);
    }
    if (!nullToAbsent || downloadedBitrate != null) {
      map['downloaded_bitrate'] = Variable<int>(downloadedBitrate);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      videoId: Value(videoId),
      title: Value(title),
      artistName: artistName == null && nullToAbsent
          ? const Value.absent()
          : Value(artistName),
      artistBrowseId: artistBrowseId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistBrowseId),
      albumName: albumName == null && nullToAbsent
          ? const Value.absent()
          : Value(albumName),
      albumBrowseId: albumBrowseId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumBrowseId),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      isLiked: Value(isLiked),
      likedAt: likedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(likedAt),
      downloadStatus: Value(downloadStatus),
      downloadAttempts: Value(downloadAttempts),
      lastDownloadError: lastDownloadError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDownloadError),
      pinned: Value(pinned),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      downloadedCodec: downloadedCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedCodec),
      downloadedBitrate: downloadedBitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedBitrate),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
    );
  }

  factory Track.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Track(
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      artistName: serializer.fromJson<String?>(json['artistName']),
      artistBrowseId: serializer.fromJson<String?>(json['artistBrowseId']),
      albumName: serializer.fromJson<String?>(json['albumName']),
      albumBrowseId: serializer.fromJson<String?>(json['albumBrowseId']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      isLiked: serializer.fromJson<bool>(json['isLiked']),
      likedAt: serializer.fromJson<DateTime?>(json['likedAt']),
      downloadStatus: serializer.fromJson<String>(json['downloadStatus']),
      downloadAttempts: serializer.fromJson<int>(json['downloadAttempts']),
      lastDownloadError: serializer.fromJson<String?>(
        json['lastDownloadError'],
      ),
      pinned: serializer.fromJson<bool>(json['pinned']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      downloadedCodec: serializer.fromJson<String?>(json['downloadedCodec']),
      downloadedBitrate: serializer.fromJson<int?>(json['downloadedBitrate']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'artistName': serializer.toJson<String?>(artistName),
      'artistBrowseId': serializer.toJson<String?>(artistBrowseId),
      'albumName': serializer.toJson<String?>(albumName),
      'albumBrowseId': serializer.toJson<String?>(albumBrowseId),
      'durationMs': serializer.toJson<int?>(durationMs),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'isLiked': serializer.toJson<bool>(isLiked),
      'likedAt': serializer.toJson<DateTime?>(likedAt),
      'downloadStatus': serializer.toJson<String>(downloadStatus),
      'downloadAttempts': serializer.toJson<int>(downloadAttempts),
      'lastDownloadError': serializer.toJson<String?>(lastDownloadError),
      'pinned': serializer.toJson<bool>(pinned),
      'localPath': serializer.toJson<String?>(localPath),
      'downloadedCodec': serializer.toJson<String?>(downloadedCodec),
      'downloadedBitrate': serializer.toJson<int?>(downloadedBitrate),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
    };
  }

  Track copyWith({
    String? videoId,
    String? title,
    Value<String?> artistName = const Value.absent(),
    Value<String?> artistBrowseId = const Value.absent(),
    Value<String?> albumName = const Value.absent(),
    Value<String?> albumBrowseId = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    bool? isLiked,
    Value<DateTime?> likedAt = const Value.absent(),
    String? downloadStatus,
    int? downloadAttempts,
    Value<String?> lastDownloadError = const Value.absent(),
    bool? pinned,
    Value<String?> localPath = const Value.absent(),
    Value<String?> downloadedCodec = const Value.absent(),
    Value<int?> downloadedBitrate = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<DateTime?> downloadedAt = const Value.absent(),
    Value<DateTime?> lastPlayedAt = const Value.absent(),
  }) => Track(
    videoId: videoId ?? this.videoId,
    title: title ?? this.title,
    artistName: artistName.present ? artistName.value : this.artistName,
    artistBrowseId: artistBrowseId.present
        ? artistBrowseId.value
        : this.artistBrowseId,
    albumName: albumName.present ? albumName.value : this.albumName,
    albumBrowseId: albumBrowseId.present
        ? albumBrowseId.value
        : this.albumBrowseId,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    isLiked: isLiked ?? this.isLiked,
    likedAt: likedAt.present ? likedAt.value : this.likedAt,
    downloadStatus: downloadStatus ?? this.downloadStatus,
    downloadAttempts: downloadAttempts ?? this.downloadAttempts,
    lastDownloadError: lastDownloadError.present
        ? lastDownloadError.value
        : this.lastDownloadError,
    pinned: pinned ?? this.pinned,
    localPath: localPath.present ? localPath.value : this.localPath,
    downloadedCodec: downloadedCodec.present
        ? downloadedCodec.value
        : this.downloadedCodec,
    downloadedBitrate: downloadedBitrate.present
        ? downloadedBitrate.value
        : this.downloadedBitrate,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
  );
  Track copyWithCompanion(TracksCompanion data) {
    return Track(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      artistName: data.artistName.present
          ? data.artistName.value
          : this.artistName,
      artistBrowseId: data.artistBrowseId.present
          ? data.artistBrowseId.value
          : this.artistBrowseId,
      albumName: data.albumName.present ? data.albumName.value : this.albumName,
      albumBrowseId: data.albumBrowseId.present
          ? data.albumBrowseId.value
          : this.albumBrowseId,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      isLiked: data.isLiked.present ? data.isLiked.value : this.isLiked,
      likedAt: data.likedAt.present ? data.likedAt.value : this.likedAt,
      downloadStatus: data.downloadStatus.present
          ? data.downloadStatus.value
          : this.downloadStatus,
      downloadAttempts: data.downloadAttempts.present
          ? data.downloadAttempts.value
          : this.downloadAttempts,
      lastDownloadError: data.lastDownloadError.present
          ? data.lastDownloadError.value
          : this.lastDownloadError,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      downloadedCodec: data.downloadedCodec.present
          ? data.downloadedCodec.value
          : this.downloadedCodec,
      downloadedBitrate: data.downloadedBitrate.present
          ? data.downloadedBitrate.value
          : this.downloadedBitrate,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Track(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('artistBrowseId: $artistBrowseId, ')
          ..write('albumName: $albumName, ')
          ..write('albumBrowseId: $albumBrowseId, ')
          ..write('durationMs: $durationMs, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('isLiked: $isLiked, ')
          ..write('likedAt: $likedAt, ')
          ..write('downloadStatus: $downloadStatus, ')
          ..write('downloadAttempts: $downloadAttempts, ')
          ..write('lastDownloadError: $lastDownloadError, ')
          ..write('pinned: $pinned, ')
          ..write('localPath: $localPath, ')
          ..write('downloadedCodec: $downloadedCodec, ')
          ..write('downloadedBitrate: $downloadedBitrate, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    videoId,
    title,
    artistName,
    artistBrowseId,
    albumName,
    albumBrowseId,
    durationMs,
    artworkUrl,
    isLiked,
    likedAt,
    downloadStatus,
    downloadAttempts,
    lastDownloadError,
    pinned,
    localPath,
    downloadedCodec,
    downloadedBitrate,
    sizeBytes,
    downloadedAt,
    lastPlayedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.artistName == this.artistName &&
          other.artistBrowseId == this.artistBrowseId &&
          other.albumName == this.albumName &&
          other.albumBrowseId == this.albumBrowseId &&
          other.durationMs == this.durationMs &&
          other.artworkUrl == this.artworkUrl &&
          other.isLiked == this.isLiked &&
          other.likedAt == this.likedAt &&
          other.downloadStatus == this.downloadStatus &&
          other.downloadAttempts == this.downloadAttempts &&
          other.lastDownloadError == this.lastDownloadError &&
          other.pinned == this.pinned &&
          other.localPath == this.localPath &&
          other.downloadedCodec == this.downloadedCodec &&
          other.downloadedBitrate == this.downloadedBitrate &&
          other.sizeBytes == this.sizeBytes &&
          other.downloadedAt == this.downloadedAt &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class TracksCompanion extends UpdateCompanion<Track> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String?> artistName;
  final Value<String?> artistBrowseId;
  final Value<String?> albumName;
  final Value<String?> albumBrowseId;
  final Value<int?> durationMs;
  final Value<String?> artworkUrl;
  final Value<bool> isLiked;
  final Value<DateTime?> likedAt;
  final Value<String> downloadStatus;
  final Value<int> downloadAttempts;
  final Value<String?> lastDownloadError;
  final Value<bool> pinned;
  final Value<String?> localPath;
  final Value<String?> downloadedCodec;
  final Value<int?> downloadedBitrate;
  final Value<int?> sizeBytes;
  final Value<DateTime?> downloadedAt;
  final Value<DateTime?> lastPlayedAt;
  final Value<int> rowid;
  const TracksCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.artistName = const Value.absent(),
    this.artistBrowseId = const Value.absent(),
    this.albumName = const Value.absent(),
    this.albumBrowseId = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.likedAt = const Value.absent(),
    this.downloadStatus = const Value.absent(),
    this.downloadAttempts = const Value.absent(),
    this.lastDownloadError = const Value.absent(),
    this.pinned = const Value.absent(),
    this.localPath = const Value.absent(),
    this.downloadedCodec = const Value.absent(),
    this.downloadedBitrate = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TracksCompanion.insert({
    required String videoId,
    required String title,
    this.artistName = const Value.absent(),
    this.artistBrowseId = const Value.absent(),
    this.albumName = const Value.absent(),
    this.albumBrowseId = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.isLiked = const Value.absent(),
    this.likedAt = const Value.absent(),
    this.downloadStatus = const Value.absent(),
    this.downloadAttempts = const Value.absent(),
    this.lastDownloadError = const Value.absent(),
    this.pinned = const Value.absent(),
    this.localPath = const Value.absent(),
    this.downloadedCodec = const Value.absent(),
    this.downloadedBitrate = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       title = Value(title);
  static Insertable<Track> custom({
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? artistName,
    Expression<String>? artistBrowseId,
    Expression<String>? albumName,
    Expression<String>? albumBrowseId,
    Expression<int>? durationMs,
    Expression<String>? artworkUrl,
    Expression<bool>? isLiked,
    Expression<DateTime>? likedAt,
    Expression<String>? downloadStatus,
    Expression<int>? downloadAttempts,
    Expression<String>? lastDownloadError,
    Expression<bool>? pinned,
    Expression<String>? localPath,
    Expression<String>? downloadedCodec,
    Expression<int>? downloadedBitrate,
    Expression<int>? sizeBytes,
    Expression<DateTime>? downloadedAt,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (artistName != null) 'artist_name': artistName,
      if (artistBrowseId != null) 'artist_browse_id': artistBrowseId,
      if (albumName != null) 'album_name': albumName,
      if (albumBrowseId != null) 'album_browse_id': albumBrowseId,
      if (durationMs != null) 'duration_ms': durationMs,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (isLiked != null) 'is_liked': isLiked,
      if (likedAt != null) 'liked_at': likedAt,
      if (downloadStatus != null) 'download_status': downloadStatus,
      if (downloadAttempts != null) 'download_attempts': downloadAttempts,
      if (lastDownloadError != null) 'last_download_error': lastDownloadError,
      if (pinned != null) 'pinned': pinned,
      if (localPath != null) 'local_path': localPath,
      if (downloadedCodec != null) 'downloaded_codec': downloadedCodec,
      if (downloadedBitrate != null) 'downloaded_bitrate': downloadedBitrate,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TracksCompanion copyWith({
    Value<String>? videoId,
    Value<String>? title,
    Value<String?>? artistName,
    Value<String?>? artistBrowseId,
    Value<String?>? albumName,
    Value<String?>? albumBrowseId,
    Value<int?>? durationMs,
    Value<String?>? artworkUrl,
    Value<bool>? isLiked,
    Value<DateTime?>? likedAt,
    Value<String>? downloadStatus,
    Value<int>? downloadAttempts,
    Value<String?>? lastDownloadError,
    Value<bool>? pinned,
    Value<String?>? localPath,
    Value<String?>? downloadedCodec,
    Value<int?>? downloadedBitrate,
    Value<int?>? sizeBytes,
    Value<DateTime?>? downloadedAt,
    Value<DateTime?>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return TracksCompanion(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      artistBrowseId: artistBrowseId ?? this.artistBrowseId,
      albumName: albumName ?? this.albumName,
      albumBrowseId: albumBrowseId ?? this.albumBrowseId,
      durationMs: durationMs ?? this.durationMs,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      isLiked: isLiked ?? this.isLiked,
      likedAt: likedAt ?? this.likedAt,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadAttempts: downloadAttempts ?? this.downloadAttempts,
      lastDownloadError: lastDownloadError ?? this.lastDownloadError,
      pinned: pinned ?? this.pinned,
      localPath: localPath ?? this.localPath,
      downloadedCodec: downloadedCodec ?? this.downloadedCodec,
      downloadedBitrate: downloadedBitrate ?? this.downloadedBitrate,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (artistBrowseId.present) {
      map['artist_browse_id'] = Variable<String>(artistBrowseId.value);
    }
    if (albumName.present) {
      map['album_name'] = Variable<String>(albumName.value);
    }
    if (albumBrowseId.present) {
      map['album_browse_id'] = Variable<String>(albumBrowseId.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (isLiked.present) {
      map['is_liked'] = Variable<bool>(isLiked.value);
    }
    if (likedAt.present) {
      map['liked_at'] = Variable<DateTime>(likedAt.value);
    }
    if (downloadStatus.present) {
      map['download_status'] = Variable<String>(downloadStatus.value);
    }
    if (downloadAttempts.present) {
      map['download_attempts'] = Variable<int>(downloadAttempts.value);
    }
    if (lastDownloadError.present) {
      map['last_download_error'] = Variable<String>(lastDownloadError.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (downloadedCodec.present) {
      map['downloaded_codec'] = Variable<String>(downloadedCodec.value);
    }
    if (downloadedBitrate.present) {
      map['downloaded_bitrate'] = Variable<int>(downloadedBitrate.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('artistBrowseId: $artistBrowseId, ')
          ..write('albumName: $albumName, ')
          ..write('albumBrowseId: $albumBrowseId, ')
          ..write('durationMs: $durationMs, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('isLiked: $isLiked, ')
          ..write('likedAt: $likedAt, ')
          ..write('downloadStatus: $downloadStatus, ')
          ..write('downloadAttempts: $downloadAttempts, ')
          ..write('lastDownloadError: $lastDownloadError, ')
          ..write('pinned: $pinned, ')
          ..write('localPath: $localPath, ')
          ..write('downloadedCodec: $downloadedCodec, ')
          ..write('downloadedBitrate: $downloadedBitrate, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumsTable extends Albums with TableInfo<$AlbumsTable, Album> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _browseIdMeta = const VerificationMeta(
    'browseId',
  );
  @override
  late final GeneratedColumn<String> browseId = GeneratedColumn<String>(
    'browse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistNameMeta = const VerificationMeta(
    'artistName',
  );
  @override
  late final GeneratedColumn<String> artistName = GeneratedColumn<String>(
    'artist_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistBrowseIdMeta = const VerificationMeta(
    'artistBrowseId',
  );
  @override
  late final GeneratedColumn<String> artistBrowseId = GeneratedColumn<String>(
    'artist_browse_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackCountMeta = const VerificationMeta(
    'trackCount',
  );
  @override
  late final GeneratedColumn<int> trackCount = GeneratedColumn<int>(
    'track_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    browseId,
    title,
    artistName,
    artistBrowseId,
    year,
    artworkUrl,
    trackCount,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'albums';
  @override
  VerificationContext validateIntegrity(
    Insertable<Album> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('browse_id')) {
      context.handle(
        _browseIdMeta,
        browseId.isAcceptableOrUnknown(data['browse_id']!, _browseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_browseIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist_name')) {
      context.handle(
        _artistNameMeta,
        artistName.isAcceptableOrUnknown(data['artist_name']!, _artistNameMeta),
      );
    }
    if (data.containsKey('artist_browse_id')) {
      context.handle(
        _artistBrowseIdMeta,
        artistBrowseId.isAcceptableOrUnknown(
          data['artist_browse_id']!,
          _artistBrowseIdMeta,
        ),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('track_count')) {
      context.handle(
        _trackCountMeta,
        trackCount.isAcceptableOrUnknown(data['track_count']!, _trackCountMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {browseId};
  @override
  Album map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Album(
      browseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}browse_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artistName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_name'],
      ),
      artistBrowseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_browse_id'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      trackCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_count'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $AlbumsTable createAlias(String alias) {
    return $AlbumsTable(attachedDatabase, alias);
  }
}

class Album extends DataClass implements Insertable<Album> {
  final String browseId;
  final String title;
  final String? artistName;
  final String? artistBrowseId;
  final int? year;
  final String? artworkUrl;
  final int trackCount;
  final DateTime? lastSyncedAt;
  const Album({
    required this.browseId,
    required this.title,
    this.artistName,
    this.artistBrowseId,
    this.year,
    this.artworkUrl,
    required this.trackCount,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['browse_id'] = Variable<String>(browseId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artistName != null) {
      map['artist_name'] = Variable<String>(artistName);
    }
    if (!nullToAbsent || artistBrowseId != null) {
      map['artist_browse_id'] = Variable<String>(artistBrowseId);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    map['track_count'] = Variable<int>(trackCount);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  AlbumsCompanion toCompanion(bool nullToAbsent) {
    return AlbumsCompanion(
      browseId: Value(browseId),
      title: Value(title),
      artistName: artistName == null && nullToAbsent
          ? const Value.absent()
          : Value(artistName),
      artistBrowseId: artistBrowseId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistBrowseId),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      trackCount: Value(trackCount),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory Album.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Album(
      browseId: serializer.fromJson<String>(json['browseId']),
      title: serializer.fromJson<String>(json['title']),
      artistName: serializer.fromJson<String?>(json['artistName']),
      artistBrowseId: serializer.fromJson<String?>(json['artistBrowseId']),
      year: serializer.fromJson<int?>(json['year']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      trackCount: serializer.fromJson<int>(json['trackCount']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'browseId': serializer.toJson<String>(browseId),
      'title': serializer.toJson<String>(title),
      'artistName': serializer.toJson<String?>(artistName),
      'artistBrowseId': serializer.toJson<String?>(artistBrowseId),
      'year': serializer.toJson<int?>(year),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'trackCount': serializer.toJson<int>(trackCount),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  Album copyWith({
    String? browseId,
    String? title,
    Value<String?> artistName = const Value.absent(),
    Value<String?> artistBrowseId = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    int? trackCount,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => Album(
    browseId: browseId ?? this.browseId,
    title: title ?? this.title,
    artistName: artistName.present ? artistName.value : this.artistName,
    artistBrowseId: artistBrowseId.present
        ? artistBrowseId.value
        : this.artistBrowseId,
    year: year.present ? year.value : this.year,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    trackCount: trackCount ?? this.trackCount,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  Album copyWithCompanion(AlbumsCompanion data) {
    return Album(
      browseId: data.browseId.present ? data.browseId.value : this.browseId,
      title: data.title.present ? data.title.value : this.title,
      artistName: data.artistName.present
          ? data.artistName.value
          : this.artistName,
      artistBrowseId: data.artistBrowseId.present
          ? data.artistBrowseId.value
          : this.artistBrowseId,
      year: data.year.present ? data.year.value : this.year,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      trackCount: data.trackCount.present
          ? data.trackCount.value
          : this.trackCount,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Album(')
          ..write('browseId: $browseId, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('artistBrowseId: $artistBrowseId, ')
          ..write('year: $year, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('trackCount: $trackCount, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    browseId,
    title,
    artistName,
    artistBrowseId,
    year,
    artworkUrl,
    trackCount,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Album &&
          other.browseId == this.browseId &&
          other.title == this.title &&
          other.artistName == this.artistName &&
          other.artistBrowseId == this.artistBrowseId &&
          other.year == this.year &&
          other.artworkUrl == this.artworkUrl &&
          other.trackCount == this.trackCount &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class AlbumsCompanion extends UpdateCompanion<Album> {
  final Value<String> browseId;
  final Value<String> title;
  final Value<String?> artistName;
  final Value<String?> artistBrowseId;
  final Value<int?> year;
  final Value<String?> artworkUrl;
  final Value<int> trackCount;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const AlbumsCompanion({
    this.browseId = const Value.absent(),
    this.title = const Value.absent(),
    this.artistName = const Value.absent(),
    this.artistBrowseId = const Value.absent(),
    this.year = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.trackCount = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumsCompanion.insert({
    required String browseId,
    required String title,
    this.artistName = const Value.absent(),
    this.artistBrowseId = const Value.absent(),
    this.year = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.trackCount = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : browseId = Value(browseId),
       title = Value(title);
  static Insertable<Album> custom({
    Expression<String>? browseId,
    Expression<String>? title,
    Expression<String>? artistName,
    Expression<String>? artistBrowseId,
    Expression<int>? year,
    Expression<String>? artworkUrl,
    Expression<int>? trackCount,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (browseId != null) 'browse_id': browseId,
      if (title != null) 'title': title,
      if (artistName != null) 'artist_name': artistName,
      if (artistBrowseId != null) 'artist_browse_id': artistBrowseId,
      if (year != null) 'year': year,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (trackCount != null) 'track_count': trackCount,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumsCompanion copyWith({
    Value<String>? browseId,
    Value<String>? title,
    Value<String?>? artistName,
    Value<String?>? artistBrowseId,
    Value<int?>? year,
    Value<String?>? artworkUrl,
    Value<int>? trackCount,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return AlbumsCompanion(
      browseId: browseId ?? this.browseId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      artistBrowseId: artistBrowseId ?? this.artistBrowseId,
      year: year ?? this.year,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      trackCount: trackCount ?? this.trackCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (browseId.present) {
      map['browse_id'] = Variable<String>(browseId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistName.present) {
      map['artist_name'] = Variable<String>(artistName.value);
    }
    if (artistBrowseId.present) {
      map['artist_browse_id'] = Variable<String>(artistBrowseId.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (trackCount.present) {
      map['track_count'] = Variable<int>(trackCount.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumsCompanion(')
          ..write('browseId: $browseId, ')
          ..write('title: $title, ')
          ..write('artistName: $artistName, ')
          ..write('artistBrowseId: $artistBrowseId, ')
          ..write('year: $year, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('trackCount: $trackCount, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlbumTracksTable extends AlbumTracks
    with TableInfo<$AlbumTracksTable, AlbumTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlbumTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _albumBrowseIdMeta = const VerificationMeta(
    'albumBrowseId',
  );
  @override
  late final GeneratedColumn<String> albumBrowseId = GeneratedColumn<String>(
    'album_browse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [albumBrowseId, videoId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'album_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlbumTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('album_browse_id')) {
      context.handle(
        _albumBrowseIdMeta,
        albumBrowseId.isAcceptableOrUnknown(
          data['album_browse_id']!,
          _albumBrowseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_albumBrowseIdMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {albumBrowseId, videoId};
  @override
  AlbumTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlbumTrack(
      albumBrowseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_browse_id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $AlbumTracksTable createAlias(String alias) {
    return $AlbumTracksTable(attachedDatabase, alias);
  }
}

class AlbumTrack extends DataClass implements Insertable<AlbumTrack> {
  final String albumBrowseId;
  final String videoId;
  final int position;
  const AlbumTrack({
    required this.albumBrowseId,
    required this.videoId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['album_browse_id'] = Variable<String>(albumBrowseId);
    map['video_id'] = Variable<String>(videoId);
    map['position'] = Variable<int>(position);
    return map;
  }

  AlbumTracksCompanion toCompanion(bool nullToAbsent) {
    return AlbumTracksCompanion(
      albumBrowseId: Value(albumBrowseId),
      videoId: Value(videoId),
      position: Value(position),
    );
  }

  factory AlbumTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlbumTrack(
      albumBrowseId: serializer.fromJson<String>(json['albumBrowseId']),
      videoId: serializer.fromJson<String>(json['videoId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'albumBrowseId': serializer.toJson<String>(albumBrowseId),
      'videoId': serializer.toJson<String>(videoId),
      'position': serializer.toJson<int>(position),
    };
  }

  AlbumTrack copyWith({
    String? albumBrowseId,
    String? videoId,
    int? position,
  }) => AlbumTrack(
    albumBrowseId: albumBrowseId ?? this.albumBrowseId,
    videoId: videoId ?? this.videoId,
    position: position ?? this.position,
  );
  AlbumTrack copyWithCompanion(AlbumTracksCompanion data) {
    return AlbumTrack(
      albumBrowseId: data.albumBrowseId.present
          ? data.albumBrowseId.value
          : this.albumBrowseId,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlbumTrack(')
          ..write('albumBrowseId: $albumBrowseId, ')
          ..write('videoId: $videoId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(albumBrowseId, videoId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlbumTrack &&
          other.albumBrowseId == this.albumBrowseId &&
          other.videoId == this.videoId &&
          other.position == this.position);
}

class AlbumTracksCompanion extends UpdateCompanion<AlbumTrack> {
  final Value<String> albumBrowseId;
  final Value<String> videoId;
  final Value<int> position;
  final Value<int> rowid;
  const AlbumTracksCompanion({
    this.albumBrowseId = const Value.absent(),
    this.videoId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlbumTracksCompanion.insert({
    required String albumBrowseId,
    required String videoId,
    required int position,
    this.rowid = const Value.absent(),
  }) : albumBrowseId = Value(albumBrowseId),
       videoId = Value(videoId),
       position = Value(position);
  static Insertable<AlbumTrack> custom({
    Expression<String>? albumBrowseId,
    Expression<String>? videoId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (albumBrowseId != null) 'album_browse_id': albumBrowseId,
      if (videoId != null) 'video_id': videoId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlbumTracksCompanion copyWith({
    Value<String>? albumBrowseId,
    Value<String>? videoId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return AlbumTracksCompanion(
      albumBrowseId: albumBrowseId ?? this.albumBrowseId,
      videoId: videoId ?? this.videoId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (albumBrowseId.present) {
      map['album_browse_id'] = Variable<String>(albumBrowseId.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlbumTracksCompanion(')
          ..write('albumBrowseId: $albumBrowseId, ')
          ..write('videoId: $videoId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistsTable extends Artists with TableInfo<$ArtistsTable, Artist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _browseIdMeta = const VerificationMeta(
    'browseId',
  );
  @override
  late final GeneratedColumn<String> browseId = GeneratedColumn<String>(
    'browse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subscribedMeta = const VerificationMeta(
    'subscribed',
  );
  @override
  late final GeneratedColumn<bool> subscribed = GeneratedColumn<bool>(
    'subscribed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("subscribed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    browseId,
    name,
    subscribed,
    artworkUrl,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Artist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('browse_id')) {
      context.handle(
        _browseIdMeta,
        browseId.isAcceptableOrUnknown(data['browse_id']!, _browseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_browseIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('subscribed')) {
      context.handle(
        _subscribedMeta,
        subscribed.isAcceptableOrUnknown(data['subscribed']!, _subscribedMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {browseId};
  @override
  Artist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Artist(
      browseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}browse_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      subscribed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}subscribed'],
      )!,
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $ArtistsTable createAlias(String alias) {
    return $ArtistsTable(attachedDatabase, alias);
  }
}

class Artist extends DataClass implements Insertable<Artist> {
  final String browseId;
  final String name;
  final bool subscribed;
  final String? artworkUrl;
  final DateTime? lastSyncedAt;
  const Artist({
    required this.browseId,
    required this.name,
    required this.subscribed,
    this.artworkUrl,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['browse_id'] = Variable<String>(browseId);
    map['name'] = Variable<String>(name);
    map['subscribed'] = Variable<bool>(subscribed);
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  ArtistsCompanion toCompanion(bool nullToAbsent) {
    return ArtistsCompanion(
      browseId: Value(browseId),
      name: Value(name),
      subscribed: Value(subscribed),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory Artist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Artist(
      browseId: serializer.fromJson<String>(json['browseId']),
      name: serializer.fromJson<String>(json['name']),
      subscribed: serializer.fromJson<bool>(json['subscribed']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'browseId': serializer.toJson<String>(browseId),
      'name': serializer.toJson<String>(name),
      'subscribed': serializer.toJson<bool>(subscribed),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  Artist copyWith({
    String? browseId,
    String? name,
    bool? subscribed,
    Value<String?> artworkUrl = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => Artist(
    browseId: browseId ?? this.browseId,
    name: name ?? this.name,
    subscribed: subscribed ?? this.subscribed,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  Artist copyWithCompanion(ArtistsCompanion data) {
    return Artist(
      browseId: data.browseId.present ? data.browseId.value : this.browseId,
      name: data.name.present ? data.name.value : this.name,
      subscribed: data.subscribed.present
          ? data.subscribed.value
          : this.subscribed,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Artist(')
          ..write('browseId: $browseId, ')
          ..write('name: $name, ')
          ..write('subscribed: $subscribed, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(browseId, name, subscribed, artworkUrl, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Artist &&
          other.browseId == this.browseId &&
          other.name == this.name &&
          other.subscribed == this.subscribed &&
          other.artworkUrl == this.artworkUrl &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class ArtistsCompanion extends UpdateCompanion<Artist> {
  final Value<String> browseId;
  final Value<String> name;
  final Value<bool> subscribed;
  final Value<String?> artworkUrl;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const ArtistsCompanion({
    this.browseId = const Value.absent(),
    this.name = const Value.absent(),
    this.subscribed = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistsCompanion.insert({
    required String browseId,
    required String name,
    this.subscribed = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : browseId = Value(browseId),
       name = Value(name);
  static Insertable<Artist> custom({
    Expression<String>? browseId,
    Expression<String>? name,
    Expression<bool>? subscribed,
    Expression<String>? artworkUrl,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (browseId != null) 'browse_id': browseId,
      if (name != null) 'name': name,
      if (subscribed != null) 'subscribed': subscribed,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistsCompanion copyWith({
    Value<String>? browseId,
    Value<String>? name,
    Value<bool>? subscribed,
    Value<String?>? artworkUrl,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return ArtistsCompanion(
      browseId: browseId ?? this.browseId,
      name: name ?? this.name,
      subscribed: subscribed ?? this.subscribed,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (browseId.present) {
      map['browse_id'] = Variable<String>(browseId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (subscribed.present) {
      map['subscribed'] = Variable<bool>(subscribed.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistsCompanion(')
          ..write('browseId: $browseId, ')
          ..write('name: $name, ')
          ..write('subscribed: $subscribed, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _browseIdMeta = const VerificationMeta(
    'browseId',
  );
  @override
  late final GeneratedColumn<String> browseId = GeneratedColumn<String>(
    'browse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerNameMeta = const VerificationMeta(
    'ownerName',
  );
  @override
  late final GeneratedColumn<String> ownerName = GeneratedColumn<String>(
    'owner_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOwnMeta = const VerificationMeta('isOwn');
  @override
  late final GeneratedColumn<bool> isOwn = GeneratedColumn<bool>(
    'is_own',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_own" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _trackCountMeta = const VerificationMeta(
    'trackCount',
  );
  @override
  late final GeneratedColumn<int> trackCount = GeneratedColumn<int>(
    'track_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    browseId,
    title,
    description,
    ownerName,
    isOwn,
    trackCount,
    artworkUrl,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('browse_id')) {
      context.handle(
        _browseIdMeta,
        browseId.isAcceptableOrUnknown(data['browse_id']!, _browseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_browseIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('owner_name')) {
      context.handle(
        _ownerNameMeta,
        ownerName.isAcceptableOrUnknown(data['owner_name']!, _ownerNameMeta),
      );
    }
    if (data.containsKey('is_own')) {
      context.handle(
        _isOwnMeta,
        isOwn.isAcceptableOrUnknown(data['is_own']!, _isOwnMeta),
      );
    }
    if (data.containsKey('track_count')) {
      context.handle(
        _trackCountMeta,
        trackCount.isAcceptableOrUnknown(data['track_count']!, _trackCountMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {browseId};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      browseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}browse_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      ownerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_name'],
      ),
      isOwn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_own'],
      )!,
      trackCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_count'],
      )!,
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final String browseId;
  final String title;
  final String? description;
  final String? ownerName;
  final bool isOwn;
  final int trackCount;
  final String? artworkUrl;
  final DateTime? lastSyncedAt;
  const Playlist({
    required this.browseId,
    required this.title,
    this.description,
    this.ownerName,
    required this.isOwn,
    required this.trackCount,
    this.artworkUrl,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['browse_id'] = Variable<String>(browseId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || ownerName != null) {
      map['owner_name'] = Variable<String>(ownerName);
    }
    map['is_own'] = Variable<bool>(isOwn);
    map['track_count'] = Variable<int>(trackCount);
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      browseId: Value(browseId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      ownerName: ownerName == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerName),
      isOwn: Value(isOwn),
      trackCount: Value(trackCount),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      browseId: serializer.fromJson<String>(json['browseId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      ownerName: serializer.fromJson<String?>(json['ownerName']),
      isOwn: serializer.fromJson<bool>(json['isOwn']),
      trackCount: serializer.fromJson<int>(json['trackCount']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'browseId': serializer.toJson<String>(browseId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'ownerName': serializer.toJson<String?>(ownerName),
      'isOwn': serializer.toJson<bool>(isOwn),
      'trackCount': serializer.toJson<int>(trackCount),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  Playlist copyWith({
    String? browseId,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> ownerName = const Value.absent(),
    bool? isOwn,
    int? trackCount,
    Value<String?> artworkUrl = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => Playlist(
    browseId: browseId ?? this.browseId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    ownerName: ownerName.present ? ownerName.value : this.ownerName,
    isOwn: isOwn ?? this.isOwn,
    trackCount: trackCount ?? this.trackCount,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      browseId: data.browseId.present ? data.browseId.value : this.browseId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      ownerName: data.ownerName.present ? data.ownerName.value : this.ownerName,
      isOwn: data.isOwn.present ? data.isOwn.value : this.isOwn,
      trackCount: data.trackCount.present
          ? data.trackCount.value
          : this.trackCount,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('browseId: $browseId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('ownerName: $ownerName, ')
          ..write('isOwn: $isOwn, ')
          ..write('trackCount: $trackCount, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    browseId,
    title,
    description,
    ownerName,
    isOwn,
    trackCount,
    artworkUrl,
    lastSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.browseId == this.browseId &&
          other.title == this.title &&
          other.description == this.description &&
          other.ownerName == this.ownerName &&
          other.isOwn == this.isOwn &&
          other.trackCount == this.trackCount &&
          other.artworkUrl == this.artworkUrl &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<String> browseId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> ownerName;
  final Value<bool> isOwn;
  final Value<int> trackCount;
  final Value<String?> artworkUrl;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.browseId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.isOwn = const Value.absent(),
    this.trackCount = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String browseId,
    required String title,
    this.description = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.isOwn = const Value.absent(),
    this.trackCount = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : browseId = Value(browseId),
       title = Value(title);
  static Insertable<Playlist> custom({
    Expression<String>? browseId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? ownerName,
    Expression<bool>? isOwn,
    Expression<int>? trackCount,
    Expression<String>? artworkUrl,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (browseId != null) 'browse_id': browseId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (ownerName != null) 'owner_name': ownerName,
      if (isOwn != null) 'is_own': isOwn,
      if (trackCount != null) 'track_count': trackCount,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<String>? browseId,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? ownerName,
    Value<bool>? isOwn,
    Value<int>? trackCount,
    Value<String?>? artworkUrl,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return PlaylistsCompanion(
      browseId: browseId ?? this.browseId,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerName: ownerName ?? this.ownerName,
      isOwn: isOwn ?? this.isOwn,
      trackCount: trackCount ?? this.trackCount,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (browseId.present) {
      map['browse_id'] = Variable<String>(browseId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (ownerName.present) {
      map['owner_name'] = Variable<String>(ownerName.value);
    }
    if (isOwn.present) {
      map['is_own'] = Variable<bool>(isOwn.value);
    }
    if (trackCount.present) {
      map['track_count'] = Variable<int>(trackCount.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('browseId: $browseId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('ownerName: $ownerName, ')
          ..write('isOwn: $isOwn, ')
          ..write('trackCount: $trackCount, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTable extends PlaylistTracks
    with TableInfo<$PlaylistTracksTable, PlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistBrowseIdMeta = const VerificationMeta(
    'playlistBrowseId',
  );
  @override
  late final GeneratedColumn<String> playlistBrowseId = GeneratedColumn<String>(
    'playlist_browse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setVideoIdMeta = const VerificationMeta(
    'setVideoId',
  );
  @override
  late final GeneratedColumn<String> setVideoId = GeneratedColumn<String>(
    'set_video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistBrowseId,
    videoId,
    setVideoId,
    position,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_browse_id')) {
      context.handle(
        _playlistBrowseIdMeta,
        playlistBrowseId.isAcceptableOrUnknown(
          data['playlist_browse_id']!,
          _playlistBrowseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playlistBrowseIdMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('set_video_id')) {
      context.handle(
        _setVideoIdMeta,
        setVideoId.isAcceptableOrUnknown(
          data['set_video_id']!,
          _setVideoIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_setVideoIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistBrowseId, setVideoId};
  @override
  PlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistTrack(
      playlistBrowseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_browse_id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      setVideoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_video_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      ),
    );
  }

  @override
  $PlaylistTracksTable createAlias(String alias) {
    return $PlaylistTracksTable(attachedDatabase, alias);
  }
}

class PlaylistTrack extends DataClass implements Insertable<PlaylistTrack> {
  final String playlistBrowseId;
  final String videoId;
  final String setVideoId;
  final int position;
  final DateTime? addedAt;
  const PlaylistTrack({
    required this.playlistBrowseId,
    required this.videoId,
    required this.setVideoId,
    required this.position,
    this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_browse_id'] = Variable<String>(playlistBrowseId);
    map['video_id'] = Variable<String>(videoId);
    map['set_video_id'] = Variable<String>(setVideoId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || addedAt != null) {
      map['added_at'] = Variable<DateTime>(addedAt);
    }
    return map;
  }

  PlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksCompanion(
      playlistBrowseId: Value(playlistBrowseId),
      videoId: Value(videoId),
      setVideoId: Value(setVideoId),
      position: Value(position),
      addedAt: addedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(addedAt),
    );
  }

  factory PlaylistTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistTrack(
      playlistBrowseId: serializer.fromJson<String>(json['playlistBrowseId']),
      videoId: serializer.fromJson<String>(json['videoId']),
      setVideoId: serializer.fromJson<String>(json['setVideoId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime?>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistBrowseId': serializer.toJson<String>(playlistBrowseId),
      'videoId': serializer.toJson<String>(videoId),
      'setVideoId': serializer.toJson<String>(setVideoId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime?>(addedAt),
    };
  }

  PlaylistTrack copyWith({
    String? playlistBrowseId,
    String? videoId,
    String? setVideoId,
    int? position,
    Value<DateTime?> addedAt = const Value.absent(),
  }) => PlaylistTrack(
    playlistBrowseId: playlistBrowseId ?? this.playlistBrowseId,
    videoId: videoId ?? this.videoId,
    setVideoId: setVideoId ?? this.setVideoId,
    position: position ?? this.position,
    addedAt: addedAt.present ? addedAt.value : this.addedAt,
  );
  PlaylistTrack copyWithCompanion(PlaylistTracksCompanion data) {
    return PlaylistTrack(
      playlistBrowseId: data.playlistBrowseId.present
          ? data.playlistBrowseId.value
          : this.playlistBrowseId,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      setVideoId: data.setVideoId.present
          ? data.setVideoId.value
          : this.setVideoId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTrack(')
          ..write('playlistBrowseId: $playlistBrowseId, ')
          ..write('videoId: $videoId, ')
          ..write('setVideoId: $setVideoId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(playlistBrowseId, videoId, setVideoId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistTrack &&
          other.playlistBrowseId == this.playlistBrowseId &&
          other.videoId == this.videoId &&
          other.setVideoId == this.setVideoId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class PlaylistTracksCompanion extends UpdateCompanion<PlaylistTrack> {
  final Value<String> playlistBrowseId;
  final Value<String> videoId;
  final Value<String> setVideoId;
  final Value<int> position;
  final Value<DateTime?> addedAt;
  final Value<int> rowid;
  const PlaylistTracksCompanion({
    this.playlistBrowseId = const Value.absent(),
    this.videoId = const Value.absent(),
    this.setVideoId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistTracksCompanion.insert({
    required String playlistBrowseId,
    required String videoId,
    required String setVideoId,
    required int position,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playlistBrowseId = Value(playlistBrowseId),
       videoId = Value(videoId),
       setVideoId = Value(setVideoId),
       position = Value(position);
  static Insertable<PlaylistTrack> custom({
    Expression<String>? playlistBrowseId,
    Expression<String>? videoId,
    Expression<String>? setVideoId,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistBrowseId != null) 'playlist_browse_id': playlistBrowseId,
      if (videoId != null) 'video_id': videoId,
      if (setVideoId != null) 'set_video_id': setVideoId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistTracksCompanion copyWith({
    Value<String>? playlistBrowseId,
    Value<String>? videoId,
    Value<String>? setVideoId,
    Value<int>? position,
    Value<DateTime?>? addedAt,
    Value<int>? rowid,
  }) {
    return PlaylistTracksCompanion(
      playlistBrowseId: playlistBrowseId ?? this.playlistBrowseId,
      videoId: videoId ?? this.videoId,
      setVideoId: setVideoId ?? this.setVideoId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistBrowseId.present) {
      map['playlist_browse_id'] = Variable<String>(playlistBrowseId.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (setVideoId.present) {
      map['set_video_id'] = Variable<String>(setVideoId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksCompanion(')
          ..write('playlistBrowseId: $playlistBrowseId, ')
          ..write('videoId: $videoId, ')
          ..write('setVideoId: $setVideoId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentlyPlayedTable extends RecentlyPlayed
    with TableInfo<$RecentlyPlayedTable, RecentlyPlayedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentlyPlayedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [videoId, playedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recently_played';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentlyPlayedData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId, playedAt};
  @override
  RecentlyPlayedData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentlyPlayedData(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at'],
      )!,
    );
  }

  @override
  $RecentlyPlayedTable createAlias(String alias) {
    return $RecentlyPlayedTable(attachedDatabase, alias);
  }
}

class RecentlyPlayedData extends DataClass
    implements Insertable<RecentlyPlayedData> {
  final String videoId;
  final DateTime playedAt;
  const RecentlyPlayedData({required this.videoId, required this.playedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  RecentlyPlayedCompanion toCompanion(bool nullToAbsent) {
    return RecentlyPlayedCompanion(
      videoId: Value(videoId),
      playedAt: Value(playedAt),
    );
  }

  factory RecentlyPlayedData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentlyPlayedData(
      videoId: serializer.fromJson<String>(json['videoId']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  RecentlyPlayedData copyWith({String? videoId, DateTime? playedAt}) =>
      RecentlyPlayedData(
        videoId: videoId ?? this.videoId,
        playedAt: playedAt ?? this.playedAt,
      );
  RecentlyPlayedData copyWithCompanion(RecentlyPlayedCompanion data) {
    return RecentlyPlayedData(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentlyPlayedData(')
          ..write('videoId: $videoId, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(videoId, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentlyPlayedData &&
          other.videoId == this.videoId &&
          other.playedAt == this.playedAt);
}

class RecentlyPlayedCompanion extends UpdateCompanion<RecentlyPlayedData> {
  final Value<String> videoId;
  final Value<DateTime> playedAt;
  final Value<int> rowid;
  const RecentlyPlayedCompanion({
    this.videoId = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentlyPlayedCompanion.insert({
    required String videoId,
    required DateTime playedAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       playedAt = Value(playedAt);
  static Insertable<RecentlyPlayedData> custom({
    Expression<String>? videoId,
    Expression<DateTime>? playedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (playedAt != null) 'played_at': playedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentlyPlayedCompanion copyWith({
    Value<String>? videoId,
    Value<DateTime>? playedAt,
    Value<int>? rowid,
  }) {
    return RecentlyPlayedCompanion(
      videoId: videoId ?? this.videoId,
      playedAt: playedAt ?? this.playedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentlyPlayedCompanion(')
          ..write('videoId: $videoId, ')
          ..write('playedAt: $playedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, lastSyncedAt, etag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String key;
  final DateTime lastSyncedAt;
  final String? etag;
  const SyncStateData({
    required this.key,
    required this.lastSyncedAt,
    this.etag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      key: Value(key),
      lastSyncedAt: Value(lastSyncedAt),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      key: serializer.fromJson<String>(json['key']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
      etag: serializer.fromJson<String?>(json['etag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
      'etag': serializer.toJson<String?>(etag),
    };
  }

  SyncStateData copyWith({
    String? key,
    DateTime? lastSyncedAt,
    Value<String?> etag = const Value.absent(),
  }) => SyncStateData(
    key: key ?? this.key,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    etag: etag.present ? etag.value : this.etag,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      key: data.key.present ? data.key.value : this.key,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      etag: data.etag.present ? data.etag.value : this.etag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('key: $key, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('etag: $etag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, lastSyncedAt, etag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.key == this.key &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.etag == this.etag);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> key;
  final Value<DateTime> lastSyncedAt;
  final Value<String?> etag;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.etag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required DateTime lastSyncedAt,
    this.etag = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<SyncStateData> custom({
    Expression<String>? key,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? etag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (etag != null) 'etag': etag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<DateTime>? lastSyncedAt,
    Value<String?>? etag,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      etag: etag ?? this.etag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('etag: $etag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $AlbumsTable albums = $AlbumsTable(this);
  late final $AlbumTracksTable albumTracks = $AlbumTracksTable(this);
  late final $ArtistsTable artists = $ArtistsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  late final $RecentlyPlayedTable recentlyPlayed = $RecentlyPlayedTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final TracksDao tracksDao = TracksDao(this as AppDatabase);
  late final PlaylistsDao playlistsDao = PlaylistsDao(this as AppDatabase);
  late final ArtistsDao artistsDao = ArtistsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tracks,
    albums,
    albumTracks,
    artists,
    playlists,
    playlistTracks,
    recentlyPlayed,
    syncState,
    settings,
  ];
}

typedef $$TracksTableCreateCompanionBuilder =
    TracksCompanion Function({
      required String videoId,
      required String title,
      Value<String?> artistName,
      Value<String?> artistBrowseId,
      Value<String?> albumName,
      Value<String?> albumBrowseId,
      Value<int?> durationMs,
      Value<String?> artworkUrl,
      Value<bool> isLiked,
      Value<DateTime?> likedAt,
      Value<String> downloadStatus,
      Value<int> downloadAttempts,
      Value<String?> lastDownloadError,
      Value<bool> pinned,
      Value<String?> localPath,
      Value<String?> downloadedCodec,
      Value<int?> downloadedBitrate,
      Value<int?> sizeBytes,
      Value<DateTime?> downloadedAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> rowid,
    });
typedef $$TracksTableUpdateCompanionBuilder =
    TracksCompanion Function({
      Value<String> videoId,
      Value<String> title,
      Value<String?> artistName,
      Value<String?> artistBrowseId,
      Value<String?> albumName,
      Value<String?> albumBrowseId,
      Value<int?> durationMs,
      Value<String?> artworkUrl,
      Value<bool> isLiked,
      Value<DateTime?> likedAt,
      Value<String> downloadStatus,
      Value<int> downloadAttempts,
      Value<String?> lastDownloadError,
      Value<bool> pinned,
      Value<String?> localPath,
      Value<String?> downloadedCodec,
      Value<int?> downloadedBitrate,
      Value<int?> sizeBytes,
      Value<DateTime?> downloadedAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> rowid,
    });

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistBrowseId => $composableBuilder(
    column: $table.artistBrowseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumBrowseId => $composableBuilder(
    column: $table.albumBrowseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLiked => $composableBuilder(
    column: $table.isLiked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get likedAt => $composableBuilder(
    column: $table.likedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadAttempts => $composableBuilder(
    column: $table.downloadAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastDownloadError => $composableBuilder(
    column: $table.lastDownloadError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadedCodec => $composableBuilder(
    column: $table.downloadedCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBitrate => $composableBuilder(
    column: $table.downloadedBitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistBrowseId => $composableBuilder(
    column: $table.artistBrowseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumBrowseId => $composableBuilder(
    column: $table.albumBrowseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLiked => $composableBuilder(
    column: $table.isLiked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get likedAt => $composableBuilder(
    column: $table.likedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadAttempts => $composableBuilder(
    column: $table.downloadAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastDownloadError => $composableBuilder(
    column: $table.lastDownloadError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadedCodec => $composableBuilder(
    column: $table.downloadedCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBitrate => $composableBuilder(
    column: $table.downloadedBitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artistBrowseId => $composableBuilder(
    column: $table.artistBrowseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumName =>
      $composableBuilder(column: $table.albumName, builder: (column) => column);

  GeneratedColumn<String> get albumBrowseId => $composableBuilder(
    column: $table.albumBrowseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isLiked =>
      $composableBuilder(column: $table.isLiked, builder: (column) => column);

  GeneratedColumn<DateTime> get likedAt =>
      $composableBuilder(column: $table.likedAt, builder: (column) => column);

  GeneratedColumn<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadAttempts => $composableBuilder(
    column: $table.downloadAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastDownloadError => $composableBuilder(
    column: $table.lastDownloadError,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get downloadedCodec => $composableBuilder(
    column: $table.downloadedCodec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedBitrate => $composableBuilder(
    column: $table.downloadedBitrate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          Track,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (Track, BaseReferences<_$AppDatabase, $TracksTable, Track>),
          Track,
          PrefetchHooks Function()
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artistName = const Value.absent(),
                Value<String?> artistBrowseId = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<String?> albumBrowseId = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<bool> isLiked = const Value.absent(),
                Value<DateTime?> likedAt = const Value.absent(),
                Value<String> downloadStatus = const Value.absent(),
                Value<int> downloadAttempts = const Value.absent(),
                Value<String?> lastDownloadError = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> downloadedCodec = const Value.absent(),
                Value<int?> downloadedBitrate = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TracksCompanion(
                videoId: videoId,
                title: title,
                artistName: artistName,
                artistBrowseId: artistBrowseId,
                albumName: albumName,
                albumBrowseId: albumBrowseId,
                durationMs: durationMs,
                artworkUrl: artworkUrl,
                isLiked: isLiked,
                likedAt: likedAt,
                downloadStatus: downloadStatus,
                downloadAttempts: downloadAttempts,
                lastDownloadError: lastDownloadError,
                pinned: pinned,
                localPath: localPath,
                downloadedCodec: downloadedCodec,
                downloadedBitrate: downloadedBitrate,
                sizeBytes: sizeBytes,
                downloadedAt: downloadedAt,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required String title,
                Value<String?> artistName = const Value.absent(),
                Value<String?> artistBrowseId = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<String?> albumBrowseId = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<bool> isLiked = const Value.absent(),
                Value<DateTime?> likedAt = const Value.absent(),
                Value<String> downloadStatus = const Value.absent(),
                Value<int> downloadAttempts = const Value.absent(),
                Value<String?> lastDownloadError = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> downloadedCodec = const Value.absent(),
                Value<int?> downloadedBitrate = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TracksCompanion.insert(
                videoId: videoId,
                title: title,
                artistName: artistName,
                artistBrowseId: artistBrowseId,
                albumName: albumName,
                albumBrowseId: albumBrowseId,
                durationMs: durationMs,
                artworkUrl: artworkUrl,
                isLiked: isLiked,
                likedAt: likedAt,
                downloadStatus: downloadStatus,
                downloadAttempts: downloadAttempts,
                lastDownloadError: lastDownloadError,
                pinned: pinned,
                localPath: localPath,
                downloadedCodec: downloadedCodec,
                downloadedBitrate: downloadedBitrate,
                sizeBytes: sizeBytes,
                downloadedAt: downloadedAt,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      Track,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (Track, BaseReferences<_$AppDatabase, $TracksTable, Track>),
      Track,
      PrefetchHooks Function()
    >;
typedef $$AlbumsTableCreateCompanionBuilder =
    AlbumsCompanion Function({
      required String browseId,
      required String title,
      Value<String?> artistName,
      Value<String?> artistBrowseId,
      Value<int?> year,
      Value<String?> artworkUrl,
      Value<int> trackCount,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });
typedef $$AlbumsTableUpdateCompanionBuilder =
    AlbumsCompanion Function({
      Value<String> browseId,
      Value<String> title,
      Value<String?> artistName,
      Value<String?> artistBrowseId,
      Value<int?> year,
      Value<String?> artworkUrl,
      Value<int> trackCount,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });

class $$AlbumsTableFilterComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get browseId => $composableBuilder(
    column: $table.browseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistBrowseId => $composableBuilder(
    column: $table.artistBrowseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlbumsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get browseId => $composableBuilder(
    column: $table.browseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistBrowseId => $composableBuilder(
    column: $table.artistBrowseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlbumsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlbumsTable> {
  $$AlbumsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get browseId =>
      $composableBuilder(column: $table.browseId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistName => $composableBuilder(
    column: $table.artistName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artistBrowseId => $composableBuilder(
    column: $table.artistBrowseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$AlbumsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlbumsTable,
          Album,
          $$AlbumsTableFilterComposer,
          $$AlbumsTableOrderingComposer,
          $$AlbumsTableAnnotationComposer,
          $$AlbumsTableCreateCompanionBuilder,
          $$AlbumsTableUpdateCompanionBuilder,
          (Album, BaseReferences<_$AppDatabase, $AlbumsTable, Album>),
          Album,
          PrefetchHooks Function()
        > {
  $$AlbumsTableTableManager(_$AppDatabase db, $AlbumsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> browseId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artistName = const Value.absent(),
                Value<String?> artistBrowseId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<int> trackCount = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion(
                browseId: browseId,
                title: title,
                artistName: artistName,
                artistBrowseId: artistBrowseId,
                year: year,
                artworkUrl: artworkUrl,
                trackCount: trackCount,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String browseId,
                required String title,
                Value<String?> artistName = const Value.absent(),
                Value<String?> artistBrowseId = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<int> trackCount = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumsCompanion.insert(
                browseId: browseId,
                title: title,
                artistName: artistName,
                artistBrowseId: artistBrowseId,
                year: year,
                artworkUrl: artworkUrl,
                trackCount: trackCount,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlbumsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlbumsTable,
      Album,
      $$AlbumsTableFilterComposer,
      $$AlbumsTableOrderingComposer,
      $$AlbumsTableAnnotationComposer,
      $$AlbumsTableCreateCompanionBuilder,
      $$AlbumsTableUpdateCompanionBuilder,
      (Album, BaseReferences<_$AppDatabase, $AlbumsTable, Album>),
      Album,
      PrefetchHooks Function()
    >;
typedef $$AlbumTracksTableCreateCompanionBuilder =
    AlbumTracksCompanion Function({
      required String albumBrowseId,
      required String videoId,
      required int position,
      Value<int> rowid,
    });
typedef $$AlbumTracksTableUpdateCompanionBuilder =
    AlbumTracksCompanion Function({
      Value<String> albumBrowseId,
      Value<String> videoId,
      Value<int> position,
      Value<int> rowid,
    });

class $$AlbumTracksTableFilterComposer
    extends Composer<_$AppDatabase, $AlbumTracksTable> {
  $$AlbumTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get albumBrowseId => $composableBuilder(
    column: $table.albumBrowseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlbumTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $AlbumTracksTable> {
  $$AlbumTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get albumBrowseId => $composableBuilder(
    column: $table.albumBrowseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlbumTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlbumTracksTable> {
  $$AlbumTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get albumBrowseId => $composableBuilder(
    column: $table.albumBrowseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$AlbumTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlbumTracksTable,
          AlbumTrack,
          $$AlbumTracksTableFilterComposer,
          $$AlbumTracksTableOrderingComposer,
          $$AlbumTracksTableAnnotationComposer,
          $$AlbumTracksTableCreateCompanionBuilder,
          $$AlbumTracksTableUpdateCompanionBuilder,
          (
            AlbumTrack,
            BaseReferences<_$AppDatabase, $AlbumTracksTable, AlbumTrack>,
          ),
          AlbumTrack,
          PrefetchHooks Function()
        > {
  $$AlbumTracksTableTableManager(_$AppDatabase db, $AlbumTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlbumTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlbumTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlbumTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> albumBrowseId = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlbumTracksCompanion(
                albumBrowseId: albumBrowseId,
                videoId: videoId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String albumBrowseId,
                required String videoId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => AlbumTracksCompanion.insert(
                albumBrowseId: albumBrowseId,
                videoId: videoId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlbumTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlbumTracksTable,
      AlbumTrack,
      $$AlbumTracksTableFilterComposer,
      $$AlbumTracksTableOrderingComposer,
      $$AlbumTracksTableAnnotationComposer,
      $$AlbumTracksTableCreateCompanionBuilder,
      $$AlbumTracksTableUpdateCompanionBuilder,
      (
        AlbumTrack,
        BaseReferences<_$AppDatabase, $AlbumTracksTable, AlbumTrack>,
      ),
      AlbumTrack,
      PrefetchHooks Function()
    >;
typedef $$ArtistsTableCreateCompanionBuilder =
    ArtistsCompanion Function({
      required String browseId,
      required String name,
      Value<bool> subscribed,
      Value<String?> artworkUrl,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });
typedef $$ArtistsTableUpdateCompanionBuilder =
    ArtistsCompanion Function({
      Value<String> browseId,
      Value<String> name,
      Value<bool> subscribed,
      Value<String?> artworkUrl,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });

class $$ArtistsTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistsTable> {
  $$ArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get browseId => $composableBuilder(
    column: $table.browseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get subscribed => $composableBuilder(
    column: $table.subscribed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtistsTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistsTable> {
  $$ArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get browseId => $composableBuilder(
    column: $table.browseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get subscribed => $composableBuilder(
    column: $table.subscribed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistsTable> {
  $$ArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get browseId =>
      $composableBuilder(column: $table.browseId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get subscribed => $composableBuilder(
    column: $table.subscribed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$ArtistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtistsTable,
          Artist,
          $$ArtistsTableFilterComposer,
          $$ArtistsTableOrderingComposer,
          $$ArtistsTableAnnotationComposer,
          $$ArtistsTableCreateCompanionBuilder,
          $$ArtistsTableUpdateCompanionBuilder,
          (Artist, BaseReferences<_$AppDatabase, $ArtistsTable, Artist>),
          Artist,
          PrefetchHooks Function()
        > {
  $$ArtistsTableTableManager(_$AppDatabase db, $ArtistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> browseId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> subscribed = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistsCompanion(
                browseId: browseId,
                name: name,
                subscribed: subscribed,
                artworkUrl: artworkUrl,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String browseId,
                required String name,
                Value<bool> subscribed = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistsCompanion.insert(
                browseId: browseId,
                name: name,
                subscribed: subscribed,
                artworkUrl: artworkUrl,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtistsTable,
      Artist,
      $$ArtistsTableFilterComposer,
      $$ArtistsTableOrderingComposer,
      $$ArtistsTableAnnotationComposer,
      $$ArtistsTableCreateCompanionBuilder,
      $$ArtistsTableUpdateCompanionBuilder,
      (Artist, BaseReferences<_$AppDatabase, $ArtistsTable, Artist>),
      Artist,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      required String browseId,
      required String title,
      Value<String?> description,
      Value<String?> ownerName,
      Value<bool> isOwn,
      Value<int> trackCount,
      Value<String?> artworkUrl,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<String> browseId,
      Value<String> title,
      Value<String?> description,
      Value<String?> ownerName,
      Value<bool> isOwn,
      Value<int> trackCount,
      Value<String?> artworkUrl,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get browseId => $composableBuilder(
    column: $table.browseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOwn => $composableBuilder(
    column: $table.isOwn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get browseId => $composableBuilder(
    column: $table.browseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOwn => $composableBuilder(
    column: $table.isOwn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get browseId =>
      $composableBuilder(column: $table.browseId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerName =>
      $composableBuilder(column: $table.ownerName, builder: (column) => column);

  GeneratedColumn<bool> get isOwn =>
      $composableBuilder(column: $table.isOwn, builder: (column) => column);

  GeneratedColumn<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>),
          Playlist,
          PrefetchHooks Function()
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> browseId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> ownerName = const Value.absent(),
                Value<bool> isOwn = const Value.absent(),
                Value<int> trackCount = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion(
                browseId: browseId,
                title: title,
                description: description,
                ownerName: ownerName,
                isOwn: isOwn,
                trackCount: trackCount,
                artworkUrl: artworkUrl,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String browseId,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> ownerName = const Value.absent(),
                Value<bool> isOwn = const Value.absent(),
                Value<int> trackCount = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                browseId: browseId,
                title: title,
                description: description,
                ownerName: ownerName,
                isOwn: isOwn,
                trackCount: trackCount,
                artworkUrl: artworkUrl,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist>),
      Playlist,
      PrefetchHooks Function()
    >;
typedef $$PlaylistTracksTableCreateCompanionBuilder =
    PlaylistTracksCompanion Function({
      required String playlistBrowseId,
      required String videoId,
      required String setVideoId,
      required int position,
      Value<DateTime?> addedAt,
      Value<int> rowid,
    });
typedef $$PlaylistTracksTableUpdateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<String> playlistBrowseId,
      Value<String> videoId,
      Value<String> setVideoId,
      Value<int> position,
      Value<DateTime?> addedAt,
      Value<int> rowid,
    });

class $$PlaylistTracksTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get playlistBrowseId => $composableBuilder(
    column: $table.playlistBrowseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setVideoId => $composableBuilder(
    column: $table.setVideoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get playlistBrowseId => $composableBuilder(
    column: $table.playlistBrowseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setVideoId => $composableBuilder(
    column: $table.setVideoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get playlistBrowseId => $composableBuilder(
    column: $table.playlistBrowseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get setVideoId => $composableBuilder(
    column: $table.setVideoId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$PlaylistTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistTracksTable,
          PlaylistTrack,
          $$PlaylistTracksTableFilterComposer,
          $$PlaylistTracksTableOrderingComposer,
          $$PlaylistTracksTableAnnotationComposer,
          $$PlaylistTracksTableCreateCompanionBuilder,
          $$PlaylistTracksTableUpdateCompanionBuilder,
          (
            PlaylistTrack,
            BaseReferences<_$AppDatabase, $PlaylistTracksTable, PlaylistTrack>,
          ),
          PlaylistTrack,
          PrefetchHooks Function()
        > {
  $$PlaylistTracksTableTableManager(
    _$AppDatabase db,
    $PlaylistTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playlistBrowseId = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String> setVideoId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime?> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistTracksCompanion(
                playlistBrowseId: playlistBrowseId,
                videoId: videoId,
                setVideoId: setVideoId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistBrowseId,
                required String videoId,
                required String setVideoId,
                required int position,
                Value<DateTime?> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistTracksCompanion.insert(
                playlistBrowseId: playlistBrowseId,
                videoId: videoId,
                setVideoId: setVideoId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistTracksTable,
      PlaylistTrack,
      $$PlaylistTracksTableFilterComposer,
      $$PlaylistTracksTableOrderingComposer,
      $$PlaylistTracksTableAnnotationComposer,
      $$PlaylistTracksTableCreateCompanionBuilder,
      $$PlaylistTracksTableUpdateCompanionBuilder,
      (
        PlaylistTrack,
        BaseReferences<_$AppDatabase, $PlaylistTracksTable, PlaylistTrack>,
      ),
      PlaylistTrack,
      PrefetchHooks Function()
    >;
typedef $$RecentlyPlayedTableCreateCompanionBuilder =
    RecentlyPlayedCompanion Function({
      required String videoId,
      required DateTime playedAt,
      Value<int> rowid,
    });
typedef $$RecentlyPlayedTableUpdateCompanionBuilder =
    RecentlyPlayedCompanion Function({
      Value<String> videoId,
      Value<DateTime> playedAt,
      Value<int> rowid,
    });

class $$RecentlyPlayedTableFilterComposer
    extends Composer<_$AppDatabase, $RecentlyPlayedTable> {
  $$RecentlyPlayedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentlyPlayedTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentlyPlayedTable> {
  $$RecentlyPlayedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentlyPlayedTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentlyPlayedTable> {
  $$RecentlyPlayedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);
}

class $$RecentlyPlayedTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentlyPlayedTable,
          RecentlyPlayedData,
          $$RecentlyPlayedTableFilterComposer,
          $$RecentlyPlayedTableOrderingComposer,
          $$RecentlyPlayedTableAnnotationComposer,
          $$RecentlyPlayedTableCreateCompanionBuilder,
          $$RecentlyPlayedTableUpdateCompanionBuilder,
          (
            RecentlyPlayedData,
            BaseReferences<
              _$AppDatabase,
              $RecentlyPlayedTable,
              RecentlyPlayedData
            >,
          ),
          RecentlyPlayedData,
          PrefetchHooks Function()
        > {
  $$RecentlyPlayedTableTableManager(
    _$AppDatabase db,
    $RecentlyPlayedTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentlyPlayedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentlyPlayedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentlyPlayedTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentlyPlayedCompanion(
                videoId: videoId,
                playedAt: playedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required DateTime playedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecentlyPlayedCompanion.insert(
                videoId: videoId,
                playedAt: playedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentlyPlayedTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentlyPlayedTable,
      RecentlyPlayedData,
      $$RecentlyPlayedTableFilterComposer,
      $$RecentlyPlayedTableOrderingComposer,
      $$RecentlyPlayedTableAnnotationComposer,
      $$RecentlyPlayedTableCreateCompanionBuilder,
      $$RecentlyPlayedTableUpdateCompanionBuilder,
      (
        RecentlyPlayedData,
        BaseReferences<_$AppDatabase, $RecentlyPlayedTable, RecentlyPlayedData>,
      ),
      RecentlyPlayedData,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String key,
      required DateTime lastSyncedAt,
      Value<String?> etag,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> key,
      Value<DateTime> lastSyncedAt,
      Value<String?> etag,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                key: key,
                lastSyncedAt: lastSyncedAt,
                etag: etag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required DateTime lastSyncedAt,
                Value<String?> etag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                key: key,
                lastSyncedAt: lastSyncedAt,
                etag: etag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db, _db.albums);
  $$AlbumTracksTableTableManager get albumTracks =>
      $$AlbumTracksTableTableManager(_db, _db.albumTracks);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db, _db.artists);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
  $$RecentlyPlayedTableTableManager get recentlyPlayed =>
      $$RecentlyPlayedTableTableManager(_db, _db.recentlyPlayed);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
