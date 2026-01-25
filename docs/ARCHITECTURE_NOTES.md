# Architecture Notes

> Technical architecture and design decisions for The Skinning Shed

## Overview

The Skinning Shed is a Flutter app with a Supabase backend. It follows a feature-based folder structure with shared services and widgets.

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Features   │  │  Services   │  │   Shared    │     │
│  │  (screens)  │  │  (API/data) │  │  (widgets)  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                      Supabase                            │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  │
│  │  Auth   │  │ Database │  │ Storage  │  │  Edge   │  │
│  │         │  │ (Postgres)│  │ (S3-like)│  │Functions│  │
│  └─────────┘  └──────────┘  └──────────┘  └─────────┘  │
└─────────────────────────────────────────────────────────┘
```

## App Shell Structure

### AppScaffold

The main layout wrapper used by all authenticated screens.

```
┌────────────────────────────────────────────────────────────┐
│ ┌────┐  ┌─────────────────────────────────────────────────┐│
│ │    │  │  [AdLeft]  [Hero Banner]  [AdRight]             ││
│ │ N  │  ├─────────────────────────────────────────────────┤│
│ │ A  │  │                                                 ││
│ │ V  │  │              Content Area                       ││
│ │    │  │              (child widget)                     ││
│ │ R  │  │                                                 ││
│ │ A  │  │                                                 ││
│ │ I  │  │                                                 ││
│ │ L  │  │                                                 ││
│ └────┘  └─────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────┘
```

**Responsive behavior**:
- Desktop (>1024px): Navigation rail + full header with ads
- Tablet (768-1024px): Navigation rail + header with right ad only
- Mobile (<768px): Bottom navigation bar + header without ads

### BannerHeader

Two factory constructors:
- `BannerHeader.authHero()` — Large banner for auth screens (no ads)
- `BannerHeader.appTop()` — Compact banner for in-app header (with ads)

### AdAwareBannerHeader

Wrapper that places ad slots on either side of the banner:

```dart
AdAwareBannerHeader(
  page: AdPages.feed,  // Targeting
  bannerWidget: BannerHeader.appTop(),
  maxBannerWidth: 900,
  adMaxWidth: 200,
  adMaxHeight: 100,
)
```

## State Management

Using **Riverpod** for dependency injection and state management.

```dart
// Provider definition
final adServiceProvider = Provider<AdService>((ref) {
  final client = SupabaseService.instance.client;
  return AdService(client);
});

// Usage in widget
class MyWidget extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final adService = ref.read(adServiceProvider);
    // ...
  }
}
```

## Weather Pipeline

### Flow

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────┐
│ User selects │────▶│ Lookup county   │────▶│ Get centroid │
│ county/date  │     │ via FIPS        │     │ (lat, lon)   │
└──────────────┘     └─────────────────┘     └──────────────┘
                                                    │
                                                    ▼
┌──────────────┐     ┌─────────────────┐     ┌──────────────┐
│ Display in   │◀────│ Create snapshot │◀────│ Select API   │
│ editable UI  │     │ with source tag │     │ tier by date │
└──────────────┘     └─────────────────┘     └──────────────┘
```

### API Tier Selection

```dart
DateTime dateTime = ...;
DateTime now = DateTime.now();
DateTime recentCutoff = now.subtract(Duration(days: 14));
DateTime historicalStart = DateTime(2022, 1, 1);

if (dateTime.isAfter(recentCutoff)) {
  // Tier 1: Forecast API with past_days
  source = 'auto_forecast_recent';
} else if (dateTime.isAfter(historicalStart)) {
  // Tier 2: Historical Forecast API
  source = 'auto_historical_forecast';
} else {
  // Tier 3: Archive API
  source = 'auto_archive';
}
```

### WeatherSnapshot Structure

```dart
class WeatherSnapshot {
  final double tempF;
  final double tempC;
  final double feelsLikeF;
  final int humidity;        // percent
  final double pressure;     // hPa
  final double pressureInHg; // inches of mercury
  final double windSpeedMph;
  final int windDirDeg;
  final String windDirText;  // N, NE, E, etc.
  final double gustsMph;
  final double precipMm;
  final int cloudPct;
  final String conditionText;
  final int conditionCode;
  final bool isHourly;
  final DateTime snapshotTime;
  final String source;       // Tier tag
}
```

## Research Aggregation

### Approach

1. Query `trophy_posts` with joined `weather_snapshots` and `moon_snapshots`
2. Bin data by dimension (moon phase, pressure range, temp range, etc.)
3. Count successes per bin
4. Apply **privacy threshold**: only show if `count >= 10`
5. Calculate lift vs baseline (optional)

### Example Bins

```dart
// Pressure bins (inHg)
final pressureBins = [
  (29.5, 29.7, 'Low'),
  (29.7, 29.9, 'Normal'),
  (29.9, 30.1, 'High'),
  (30.1, 30.5, 'Very High'),
];

// Moon phase bins
final moonBins = [
  (0, 'New Moon'),
  (1, 'Waxing Crescent'),
  (2, 'First Quarter'),
  // ...
];
```

### Privacy Gate

```dart
Widget buildAggregation(int count, double percentage) {
  if (count < 10) {
    return Text('Insufficient data');
  }
  return Text('$percentage% success ($count samples)');
}
```

## Ads System

### Architecture

```
┌──────────────────┐     ┌──────────────────┐
│    ad_slots      │     │    ad_share      │
│    (table)       │     │    (bucket)      │
├──────────────────┤     ├──────────────────┤
│ page: "feed"     │────▶│ feed/left.png    │
│ position: "left" │     │ feed/right.png   │
│ storage_path     │     │ weather/left.png │
│ click_url        │     │ ...              │
│ enabled          │     └──────────────────┘
│ starts_at        │
│ ends_at          │
│ priority         │
└──────────────────┘
```

### URL Resolution

```dart
const bool kAdsBucketPublic = bool.fromEnvironment(
  'ADS_BUCKET_PUBLIC',
  defaultValue: true,
);

Future<String?> _resolveAdUrl(String storagePath) async {
  if (kAdsBucketPublic) {
    return client.storage.from('ad_share').getPublicUrl(storagePath);
  }
  return await client.storage.from('ad_share').createSignedUrl(storagePath, 3600);
}
```

### Caching

- Metadata cached in-memory for 10 minutes
- Images cached by Flutter's image cache
- Cache key: `"$page:$position"`

## Database Schema (Key Tables)

### trophy_posts
```sql
id uuid PRIMARY KEY
user_id uuid REFERENCES auth.users
category text NOT NULL
state text NOT NULL
county text NOT NULL
county_fips text
harvest_date date NOT NULL
harvest_time time
-- ... scoring fields ...
cover_photo_path text
created_at timestamptz
```

### weather_snapshots
```sql
id uuid PRIMARY KEY
post_id uuid REFERENCES trophy_posts
temp_f numeric
temp_c numeric
pressure_hpa numeric
pressure_inhg numeric
humidity_pct integer
wind_speed numeric
wind_dir_deg integer
wind_dir_text text
condition_text text
condition_code text
source text  -- API tier tag
snapshot_time timestamptz
```

### moon_snapshots
```sql
id uuid PRIMARY KEY
post_id uuid REFERENCES trophy_posts
phase_name text
phase_number integer
illumination numeric
is_waxing boolean
```

### ad_slots
```sql
id uuid PRIMARY KEY
page text NOT NULL
position text NOT NULL CHECK (position IN ('left', 'right'))
storage_path text NOT NULL
click_url text
enabled boolean DEFAULT true
starts_at timestamptz
ends_at timestamptz
priority integer DEFAULT 100
label text
UNIQUE (page, position)
```

## Regulations Worker & Job Queue

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter Admin UI                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Run GPT Discovery│  │ View Progress   │  │ Resume/Unstick  │  │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  │
└───────────┼────────────────────┼────────────────────┼───────────┘
            │                    │                    │
            ▼                    ▼                    ▼
┌───────────────────────────────────────────────────────────────────┐
│                      Supabase Database                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ regs_admin_runs │  │    regs_jobs    │  │ regs_job_events │  │
│  │ (run lifecycle) │  │ (job queue)     │  │ (logs)          │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                   │
│  RPCs: regs_claim_job, regs_complete_job, regs_admin_requeue_run │
└───────────────────────────────────────────────────────────────────┘
            │
            │  Poll every 2s
            ▼
┌───────────────────────────────────────────────────────────────────┐
│                     Regs Worker (Node.js)                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Job Claim Loop  │  │ Discovery Proc  │  │ Extraction Proc │  │
│  │ (regs_claim_job)│  │ (GPT + Crawl)   │  │ (GPT + Parse)   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

### Job Claim Process (regs_claim_job RPC)

The `regs_claim_job` RPC is the atomic heart of the job queue:

1. **Auto-unstick**: Requeues jobs stuck in 'running' > 15 min
2. **Auto-resume**: Sets stalled runs back to 'running' if queued jobs exist
3. **Atomic claim**: Uses `FOR UPDATE SKIP LOCKED` to claim one job
4. **Updates**: Sets `status='running'`, `locked_at`, `locked_by`, increments `attempts`

```sql
UPDATE regs_jobs SET status = 'running', locked_at = NOW(), ...
WHERE id = (
  SELECT j.id FROM regs_jobs j
  JOIN regs_admin_runs r ON r.id = j.run_id
  WHERE j.status = 'queued' AND r.status IN ('running', 'queued')
  FOR UPDATE OF j SKIP LOCKED
  LIMIT 1
) RETURNING *;
```

### Self-Healing Guarantees

The system is designed to self-heal without manual intervention:

| Scenario | Auto-Fix |
|----------|----------|
| Job stuck running > 15 min | Requeued on next claim_job call |
| Run status not 'running' but has queued jobs | Auto-set to 'running' |
| Worker crashes mid-job | Job requeued after timeout |
| UI error during start | Run remains valid, jobs still queued |

### Admin RPCs

- **regs_admin_requeue_run(p_run_id, p_stuck_minutes)**
  - Requeues jobs stuck > N minutes
  - Clears stale locks from terminal jobs
  - Ensures run status = 'running'

- **regs_admin_force_restart_run(p_run_id)**
  - Requeues ALL non-terminal jobs (keeps done/skipped)
  - Resets run to 'running'

### Progress Tracking

Progress is computed from regs_jobs, not fragile UI state:

```sql
SELECT 
  COUNT(*) FILTER (WHERE status = 'queued') as queued,
  COUNT(*) FILTER (WHERE status = 'running') as running,
  COUNT(*) FILTER (WHERE status = 'done') as done,
  COUNT(*) FILTER (WHERE status IN ('done','failed','skipped','canceled')) as terminal
FROM regs_jobs WHERE run_id = ?
```

## Error Handling Patterns

### Service Layer

```dart
Future<T?> safeCall<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } catch (e) {
    print('Error: $e');
    return null;
  }
}
```

### UI Layer

```dart
// Always check for null from services
final result = await service.fetchData();
if (result == null) {
  showSnackBar('Failed to load data');
  return;
}
// Use result...
```

### Bootstrap Error View

Must wrap in `Directionality` since it renders before `MaterialApp`:

```dart
return Directionality(
  textDirection: TextDirection.ltr,
  child: Scaffold(
    // Error UI...
  ),
);
```

## File Organization

```
lib/
├── app/
│   ├── app.dart              # MaterialApp setup
│   ├── bootstrap_screen.dart # Startup gate
│   ├── router.dart           # GoRouter config
│   └── theme/                # Colors, spacing, typography
├── features/
│   ├── auth/                 # Login, register
│   ├── feed/                 # Main feed
│   ├── post/                 # Trophy posting
│   ├── weather/              # Weather screen
│   ├── research/             # Research/patterns
│   └── ...
├── services/
│   ├── supabase_service.dart # Supabase client
│   ├── weather_service.dart  # Weather API
│   ├── trophy_service.dart   # Trophy CRUD
│   └── ad_service.dart       # Ad management
└── shared/
    ├── widgets/              # Reusable widgets
    └── utils/                # Helper functions
```
