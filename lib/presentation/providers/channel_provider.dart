import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/channel.dart';

final selectedChannelProvider      = StateProvider<Channel?>     ((ref) => null);
final currentChannelListProvider   = StateProvider<List<Channel>>((ref) => []);
final currentChannelIndexProvider  = StateProvider<int>          ((ref) => 0);
