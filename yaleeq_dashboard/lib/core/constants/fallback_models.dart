import 'package:yaleeq_dashboard/features/try_on/domain/entities/model_info.dart';

/// Hardcoded fallback models list — mirrors `api/models_registry.py`.
///
/// Used when the API is unreachable so the carousel still renders
/// with local asset images.
const List<ModelInfo> fallbackModels = [
  // ── Women ──────────────────────────────────────────────
  ModelInfo(
    id: 'woman_01',
    name: 'Woman - Style 1',
    gender: 'female',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/woman_01/thumbnail',
  ),
  ModelInfo(
    id: 'woman_02',
    name: 'Woman - Style 2',
    gender: 'female',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/woman_02/thumbnail',
  ),
  // ── Men ────────────────────────────────────────────────
  ModelInfo(
    id: 'man_01',
    name: 'Man - Casual',
    gender: 'male',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/man_01/thumbnail',
  ),
  // ── Kids ───────────────────────────────────────────────
  ModelInfo(
    id: 'boy_01',
    name: 'Little Boy',
    gender: 'male',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/boy_01/thumbnail',
  ),
  ModelInfo(
    id: 'girl_01',
    name: 'Little Girl',
    gender: 'female',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/girl_01/thumbnail',
  ),
  ModelInfo(
    id: 'boy_02',
    name: 'Mid Boy',
    gender: 'male',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/boy_02/thumbnail',
  ),
  ModelInfo(
    id: 'girl_02',
    name: 'Mid Girl',
    gender: 'female',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/girl_02/thumbnail',
  ),
  // ── Mannequins ─────────────────────────────────────────
  ModelInfo(
    id: 'mannequin_women',
    name: 'Women Mannequin',
    gender: 'female',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/mannequin_women/thumbnail',
  ),
  ModelInfo(
    id: 'mannequin_man',
    name: 'Man Mannequin',
    gender: 'male',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/mannequin_man/thumbnail',
  ),
  ModelInfo(
    id: 'mannequin_child',
    name: 'Child Mannequin',
    gender: 'unisex',
    supportedCategories: ['tops', 'bottoms', 'one-pieces'],
    thumbnailUrl: '/api/v1/models/mannequin_child/thumbnail',
  ),
];
