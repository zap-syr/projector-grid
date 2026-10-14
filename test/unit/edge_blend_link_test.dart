import 'package:flutter_test/flutter_test.dart';
import 'package:projector_grid/features/workspace/domain/blend_edge.dart';
import 'package:projector_grid/features/workspace/domain/edge_blend_pair.dart';
import 'package:projector_grid/features/workspace/domain/projector_node.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/common/projector_settings_client.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/black_level_state.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_link.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_side.dart';
import 'package:projector_grid/features/workspace/presentation/widgets/edge_blending/edge_blend_state.dart';

import '../helpers/fake_protocol_service.dart';

const _a = ProjectorNode(
  id: 'a',
  name: 'PRJ-01',
  ipAddress: '10.0.0.1',
  x: 0,
  y: 0,
);
const _b = ProjectorNode(
  id: 'b',
  name: 'PRJ-02',
  ipAddress: '10.0.0.2',
  x: 200,
  y: 0,
);

void main() {
  late FakeProtocolService service;
  late List<EdgeBlendSide> sides;

  EdgeBlendSide side(ProjectorNode node) => EdgeBlendSide(
    node: node,
    client: ProjectorSettingsClient(
      service: service,
      node: node,
      onFailure: (_) {},
    ),
  );

  /// Side by side, both WUXGA unless [qidB] says otherwise: on both, Left
  /// and Right enabled with width 192; B.Left start 50.
  Future<void> load({String qidB = 'PT-RZ34KE'}) async {
    service = FakeProtocolService();
    service.rawResponses.addAll({
      'QVX:EDBI0': 'EDBI0=+00001',
      'QID': 'PT-RZ34KE',
      'QGR': '1',
      'QGL': '1',
      'QVX:ERWI0': 'ERWI0=+00192',
      'QVX:ELWI0': 'ELWI0=+00192',
    });
    service.rawResponsesByIp[_b.ipAddress] = {'QID': qidB, 'QEL': '50'};
    sides = [side(_a), side(_b)];
    await Future.wait([for (final s in sides) s.load()]);
    service.sentRaw.clear();
  }

  tearDown(() {
    for (final s in sides) {
      s.dispose();
    }
  });

  EdgeBlendLink link({bool on = true}) => EdgeBlendLink(
    sides: sides,
    arrangement: PairArrangement.sideBySide,
    on: on,
  );

  List<String> sentTo(ProjectorNode node) => [
    for (final (ip, cmd) in service.sentRaw)
      if (ip == node.ipAddress) cmd,
  ];

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'a linked Width mirrors to the facing edge, preview and write',
    () async {
      await load();
      link()
        ..preview(0, BlendEdge.right, EdgePart.width, 300)
        ..commit(0, BlendEdge.right, EdgePart.width);
      expect(sides[1].blend[BlendEdge.left].width, 300);
      await settle();
      expect(sentTo(_a), ['VXX:ERWI0=+00300']);
      expect(sentTo(_b), ['VXX:ELWI0=+00300']);
    },
  );

  test('works from either side', () async {
    await load();
    link().preview(1, BlendEdge.left, EdgePart.width, 250);
    expect(sides[0].blend[BlendEdge.right].width, 250);
  });

  test('Start is never mirrored', () async {
    await load();
    link().preview(0, BlendEdge.right, EdgePart.start, 40);
    expect(sides[1].blend[BlendEdge.left].start, 50);
  });

  test('only the facing edge is linked', () async {
    await load();
    link().preview(0, BlendEdge.left, EdgePart.width, 100);
    expect(sides[1].blend[BlendEdge.right].width, 192);
  });

  test('enable mirrors', () async {
    await load();
    link().setEnabled(0, BlendEdge.right, false);
    expect(sides[1].blend[BlendEdge.left].enabled, isFalse);
  });

  test('Link off mirrors nothing', () async {
    await load();
    link(on: false).preview(0, BlendEdge.right, EdgePart.width, 300);
    expect(sides[1].blend[BlendEdge.left].width, 192);
  });

  test('mixed rasters: Link unavailable', () async {
    await load(qidB: 'PT-RQ25KE');
    final l = link();
    expect(l.available, isFalse);
    expect(l.mixedRasters, isTrue);
    l.preview(0, BlendEdge.right, EdgePart.width, 300);
    expect(sides[1].blend[BlendEdge.left].width, 192);
  });

  test('linked max is the smaller of the two §8 limits', () async {
    await load();
    // B.Right line at 1000 and B.Left start 50 leave B.Left width ≤ 870.
    sides[1].preview(BlendEdge.right, EdgePart.width, 1000);
    expect(link().maxFor(0, BlendEdge.right, EdgePart.width), 870);
    // A's own: 1920 − A.Left line at 192.
    expect(link(on: false).maxFor(0, BlendEdge.right, EdgePart.width), 1728);
  });

  test('reset clears Start here, only Width on the partner', () async {
    await load();
    link().resetEdge(1, BlendEdge.left);
    expect(sides[1].blend[BlendEdge.left].start, 0);
    expect(sides[0].blend[BlendEdge.right].width, 0);
    expect(sides[0].blend[BlendEdge.right].start, 0);
  });

  test("turning Link on copies the active projector's facing edge", () async {
    await load();
    sides[0]
      ..preview(BlendEdge.right, EdgePart.width, 300)
      ..commit(BlendEdge.right, EdgePart.width);
    await settle();
    service.sentRaw.clear();
    link().copyFrom(0);
    expect(sides[1].blend[BlendEdge.left].width, 300);
    await settle();
    expect(sentTo(_b), ['VXX:ELWI0=+00300']);
  });

  test("the facing edge's overlapped level mirrors as a whole", () async {
    await load();
    service.rawResponses['QJI'] = '000,000,000,000';
    await Future.wait([for (final s in sides) s.loadBlack()]);
    service.sentRaw.clear();
    final l = link()
      ..setInterlocked(0, LevelSlot.right, true)
      ..previewLevel(0, LevelSlot.right, RgbChannel.g, 12)
      ..commitLevel(0, LevelSlot.right);
    expect(sides[1].black![LevelSlot.left].interlocked, isTrue);
    expect(sides[1].black![LevelSlot.left].value, (w: 12, r: 12, g: 12, b: 12));
    await settle();
    expect(sentTo(_b), contains('VXX:EBBS2=012,012,012,012'));
    // The border level isn't per edge: never mirrored.
    l.previewLevel(0, LevelSlot.border, RgbChannel.r, 30);
    expect(sides[1].black![LevelSlot.border].value.r, 0);
  });

  test('the level copy waits for both Black Level loads', () async {
    await load();
    service.rawResponses['QJI'] = '000,000,000,000';
    service.rawResponsesByIp[_a.ipAddress] = {
      'QVX:EBBS3': 'EBBS3=010,010,010,010',
    };
    await sides[0].loadBlack();
    expect(link().copyLevelFrom(0), isFalse);
    await sides[1].loadBlack();
    service.sentRaw.clear();
    expect(link().copyLevelFrom(0), isTrue);
    expect(sides[1].black![LevelSlot.left].value.w, 10);
    await settle();
    expect(sentTo(_b), ['VXX:EBBS2=010,010,010,010']);
  });

  test('stacked links A.Lower with B.Upper', () async {
    await load();
    EdgeBlendLink(
      sides: sides,
      arrangement: PairArrangement.stacked,
      on: true,
    ).preview(0, BlendEdge.lower, EdgePart.width, 80);
    expect(sides[1].blend[BlendEdge.upper].width, 80);
  });
}
