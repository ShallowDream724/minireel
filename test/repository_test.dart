import 'package:flutter_test/flutter_test.dart';
import 'package:minireel/data/repositories/drama_repository.dart';
import 'package:minireel/data/sources/source_adapter.dart';
import 'package:minireel/domain/models/drama.dart';

import 'support/fakes.dart';

void main() {
  test(
    'a failed refresh keeps cached catalog and independent favorites',
    () async {
      final store = MemoryStore()
        ..catalog[sampleDrama.id] = sampleDrama
        ..favorites[sampleDrama.id] = sampleDrama;
      final source = FakeSource()..failCatalog = true;
      final repo = DramaRepository(SourceRegistry([source]), store);
      addTearDown(repo.dispose);
      await repo.loadCache();
      await repo.refresh();
      expect(repo.catalog.single.id, sampleDrama.id);
      expect(repo.errors.length, 4);
      expect(repo.refreshing, false);
      await repo.clearCache();
      expect(repo.catalog, isEmpty);
      expect(store.favorites, isNotEmpty);
    },
  );

  test(
    'partial category failure retains old rows while other categories update',
    () async {
      final store = MemoryStore()..catalog[sampleDrama.id] = sampleDrama;
      final source = FakeSource();
      source.catalogLoader = (channel, _) async => channel == DramaChannel.real
          ? [
              sampleDrama,
              const Drama(
                id: 'test:200',
                source: 'test',
                sourceId: '200',
                title: '新剧',
              ),
            ]
          : [];
      final repo = DramaRepository(SourceRegistry([source]), store);
      addTearDown(repo.dispose);
      await repo.loadCache();
      await repo.refresh();
      expect(repo.catalog.length, 2);
      await repo.loadMore(channel: DramaChannel.real);
      expect(repo.catalog.length, 2);
      expect(repo.hasMoreFor(DramaChannel.real), false);
    },
  );
}
