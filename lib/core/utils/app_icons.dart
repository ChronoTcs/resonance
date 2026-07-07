// ponytail: single source of truth for icon constants used in 3+ places
import 'package:resonance_app/core/utils/uicons.dart';
import 'package:flutter/material.dart';

abstract class AppIcons {
  static IconData get music          => UIcons.regular.music;
  static IconData get close          => UIcons.regular.cross_small;
  static IconData get download       => UIcons.regular.download;
  static IconData get refresh        => UIcons.regular.refresh;
  static IconData get add            => UIcons.regular.add;
  static IconData get search         => UIcons.regular.search;
  static IconData get trash          => UIcons.regular.trash;
  static IconData get playlist       => UIcons.regular.list_music;
  static IconData get moreVert       => UIcons.regular.menu_dots_vertical;
  static IconData get equalizer      => UIcons.regular.settings_sliders;
  static IconData get globe          => UIcons.regular.globe;
  static IconData get collapseDown   => UIcons.regular.angle_small_down;
  static IconData get chevronRight   => UIcons.regular.angle_small_right;
  static IconData get back           => UIcons.regular.arrow_small_left;
  static IconData get video          => UIcons.regular.video_camera;
  static IconData get shuffle        => UIcons.regular.shuffle;
  static IconData get expand         => UIcons.regular.expand;
  static IconData get compress       => UIcons.regular.compress;
  static IconData get microphone     => UIcons.regular.microphone;
  static IconData get folder         => UIcons.regular.folder;
  static IconData get rotate         => UIcons.regular.rotate_right;
  static IconData get headphones     => UIcons.regular.headphones;
  static IconData get storage        => UIcons.regular.hdd;
}
