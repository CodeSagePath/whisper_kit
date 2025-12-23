# WhisperKit Performance Optimization Guide

This guide covers best practices for optimizing WhisperKit performance on mobile devices.

## Table of Contents

1. [Model Selection](#model-selection)
2. [Thread Configuration](#thread-configuration)
3. [Memory Management](#memory-management)
4. [Audio Preprocessing](#audio-preprocessing)
5. [Batch Processing](#batch-processing)
6. [Caching Strategies](#caching-strategies)
7. [Device-Specific Optimization](#device-specific-optimization)
8. [Benchmarking](#benchmarking)

---

## Model Selection

### Model Comparison

| Model | Size | RTF* | Memory | Use Case |
|-------|------|------|--------|----------|
| tiny | 75MB | 0.1x | ~300MB | Real-time, low-end devices |
| base | 142MB | 0.2x | ~500MB | General purpose (recommended) |
| small | 466MB | 0.5x | ~1GB | Higher accuracy needs |
| medium | 1.5GB | 1.5x | ~2.5GB | Professional transcription |
| large | 3GB | 3x | ~5GB | Maximum accuracy |

*RTF (Real-Time Factor): Lower is better. 0.5x means 30s audio processes in 15s.

### Choosing the Right Model

```dart
// Use adaptive processing to choose automatically
final caps = await DeviceCapabilities.detect();
final processor = AdaptiveProcessor();
final settings = processor.getOptimalSettings(caps);

print('Recommended: ${settings.recommendedModel}');
```

**Guidelines:**
- **Low-end devices (<2GB RAM)**: Use `tiny`
- **Mid-range devices (2-4GB RAM)**: Use `base`
- **High-end devices (4-8GB RAM)**: Use `small` or `medium`
- **Tablets/Desktop-class (8GB+ RAM)**: Use `medium` or `large`

---

## Thread Configuration

### Optimal Thread Counts

```dart
// Let the system recommend
final threads = ThreadingConfig.recommendedThreads();

// Or configure manually
final config = ThreadingConfig(
  transcriptionThreads: 4,
  audioProcessingThreads: 2,
);
```

**Recommendations by Device:**

| Device Cores | Transcription Threads | Audio Threads |
|--------------|----------------------|---------------|
| 2-4 cores | 2 | 1 |
| 4-6 cores | 4 | 2 |
| 8+ cores | 6 | 3 |

### Thread Impact on Performance

```
Threads  | Speed    | Battery  | Heat
---------|----------|----------|--------
2        | Slow     | Low      | Cool
4        | Good     | Medium   | Warm
6        | Fast     | High     | Hot
8        | Fastest  | Highest  | Very Hot
```

**Best Practice:** Use maximum threads minus 2 to leave room for UI responsiveness.

---

## Memory Management

### Monitoring Memory Usage

```dart
// Check model memory requirements
final required = MemoryOptimizer.estimateModelMemory('base');
print('Model needs: ${required}MB');

// Check if device can handle it
final canLoad = MemoryOptimizer.canLoadModel('small', availableMemoryMB);
```

### Memory Optimization Strategies

#### 1. Load Models On-Demand

```dart
// Don't keep models in memory when not needed
await whisper.initModel();
// ... use it ...
// Model is released when Whisper instance is garbage collected
```

#### 2. Process in Chunks

```dart
// For large files, process in chunks
if (LargeFileHandler.needsChunking(audioPath)) {
  final config = LargeFileHandler.getRecommendedConfig(fileSize);
  // Process chunks sequentially to manage memory
}
```

#### 3. Clear Caches

```dart
// Periodically clean up
await TranscriptionCache.cleanup();
await SecureCleanup.cleanTempAudioFiles('/tmp/whisper');
```

### Memory Budgets

```dart
final config = MemoryConfig(
  maxModelCacheMB: 500,      // Max for cached models
  maxAudioBufferMB: 100,     // Max for audio buffers
  lowMemoryThreshold: 200,   // Trigger cleanup below this
);
```

---

## Audio Preprocessing

### Optimal Audio Format

For best performance:

```
Format: WAV
Sample Rate: 16kHz
Channels: Mono
Bit Depth: 16-bit PCM
```

### File Size Guidelines

| Duration | Size (16kHz WAV) | Processing Time (base) |
|----------|------------------|----------------------|
| 30 sec | ~1MB | ~6 sec |
| 5 min | ~10MB | ~1 min |
| 30 min | ~60MB | ~6 min |
| 1 hour | ~115MB | ~12 min |

### Large File Handling

```dart
// Check file size category
final category = LargeFileHandler.categorize(fileSizeBytes);

switch (category) {
  case FileSizeCategory.small:
    // Process directly
    break;
  case FileSizeCategory.large:
  case FileSizeCategory.veryLarge:
    // Use chunking
    final config = LargeFileHandler.getRecommendedConfig(fileSizeBytes);
    // Process with overlap for context
    break;
}
```

---

## Batch Processing

### Sequential vs Parallel

```dart
// Sequential (lower memory, slower)
final results = await transcriber.transcribeAll(
  files,
  options: BatchOptions(parallel: false),
);

// Parallel (faster, more memory)
final results = await transcriber.transcribeAll(
  files,
  options: BatchOptions(
    parallel: true,
    maxConcurrency: 2,  // Limit concurrent operations
  ),
);
```

### Queue Management

```dart
final queue = TranscriptionQueue(
  maxConcurrent: 2,  // Process 2 at a time
  onItemCompleted: (result) {
    print('Completed: ${result.id}');
  },
);

// Add items with priority
queue.add(urgentAudio, priority: TranscriptionPriority.urgent);
queue.add(normalAudio, priority: TranscriptionPriority.normal);
```

### Batch Performance Tips

1. **Sort by size** - Process smaller files first for quick wins
2. **Limit concurrency** - Usually 2-3 is optimal
3. **Use priority** - Process important files first
4. **Handle failures** - Use retry with backoff

---

## Caching Strategies

### When to Cache

- ✅ Repeated transcriptions of same audio
- ✅ User-generated content that may be replayed
- ✅ Reference/training audio
- ❌ One-time processing
- ❌ Real-time streams

### Cache Configuration

```dart
final cache = TranscriptionCache(
  directory: await getApplicationDocumentsDirectory(),
  maxEntries: 100,           // Limit cache size
  expiration: Duration(days: 7),  // Auto-expire old entries
);
```

### Cache Hit Rate Optimization

```dart
// Generate consistent cache keys
String cacheKey(String audioPath) {
  final file = File(audioPath);
  final stat = file.statSync();
  // Include modification time to invalidate on changes
  return '${audioPath}_${stat.modified.millisecondsSinceEpoch}';
}
```

---

## Device-Specific Optimization

### Detecting Device Capabilities

```dart
final caps = await DeviceCapabilities.detect();

print('Processors: ${caps.processorCount}');
print('Memory: ${caps.availableMemory}MB');
print('Tier: ${caps.performanceTier}');
```

### Presets by Device Tier

```dart
TranscribeRequest requestForDevice(String audioPath, DeviceCapabilities caps) {
  switch (caps.performanceTier) {
    case PerformanceTier.low:
      return TranscriptionPreset.lowMemory.toRequest(audioPath);
    case PerformanceTier.medium:
      return TranscriptionPreset.balanced.toRequest(audioPath);
    case PerformanceTier.high:
      return TranscriptionPreset.accurate.toRequest(audioPath);
  }
}
```

### Platform-Specific Considerations

#### Android

```dart
// Check for low memory mode
if (Platform.isAndroid) {
  // Android may kill background processes
  // Keep foreground notification for long transcriptions
  BackgroundTranscription.instance.startTranscription(
    audioPath: audioPath,
    config: BackgroundConfig(showNotification: true),
  );
}
```

#### iOS

```dart
if (Platform.isIOS) {
  // iOS has stricter memory limits
  // Prefer smaller models on older devices
  final isOldDevice = caps.availableMemory < 2048;
  final model = isOldDevice ? WhisperModel.tiny : WhisperModel.base;
}
```

---

## Benchmarking

### Running Benchmarks

```dart
final benchmarker = Benchmarker(
  config: TranscriptionBenchmarkConfig(
    warmupRuns: 1,
    measurementRuns: 3,
    cooldownMs: 500,
  ),
);

final result = await benchmarker.run('base_model_test', () async {
  await whisper.transcribe(
    transcribeRequest: TranscribeRequest(audio: testAudio),
  );
});

print('Average: ${result.averageDuration.inMilliseconds}ms');
print('Ops/sec: ${result.opsPerSecond}');
```

### Model Comparison

```dart
final benchmarks = <ModelBenchmark>[];

for (final model in ['tiny', 'base', 'small']) {
  final whisper = Whisper(model: WhisperModel.values.byName(model));
  await whisper.initModel();
  
  final sw = Stopwatch()..start();
  await whisper.transcribe(...);
  sw.stop();
  
  benchmarks.add(ModelBenchmark(
    modelName: model,
    audioFile: testAudio,
    transcriptionTime: sw.elapsed,
    audioDuration: audioDuration,
  ));
}

// Compare results
print(BenchmarkComparison.compare(benchmarks));
```

### Key Metrics to Track

| Metric | Target | Warning |
|--------|--------|---------|
| Real-Time Factor | <0.5x | >1.0x |
| Memory Peak | <1GB | >2GB |
| First Word Latency | <1s | >3s |
| Success Rate | >99% | <95% |

---

## Performance Checklist

### Before Production

- [ ] Tested on lowest-spec target device
- [ ] Memory profiled with large files
- [ ] Benchmarked all supported models
- [ ] Implemented proper error handling
- [ ] Added telemetry for performance monitoring
- [ ] Configured appropriate caching
- [ ] Tested background processing

### Runtime Monitoring

```dart
// Track performance in production
Telemetry.instance.setEnabled(true);

await Telemetry.instance.trackTranscriptionStart(
  modelName: 'base',
);

// Track completion with metrics
await Telemetry.instance.trackTranscriptionComplete(
  audioLengthMs: audioDuration.inMilliseconds,
  wordCount: response.text.split(' ').length,
);
```

---

## Summary

### Quick Optimization Tips

1. **Start with `base` model** - Best balance of speed/accuracy
2. **Use 4 threads** - Good default for most devices
3. **Enable caching** - Avoid reprocessing
4. **Process in background** - Don't block UI
5. **Clean up regularly** - Prevent memory bloat
6. **Monitor in production** - Track real-world performance

### Performance vs Quality Trade-offs

```
Speed Priority:
  Model: tiny | Threads: 6 | Cache: Yes

Balanced:
  Model: base | Threads: 4 | Cache: Yes

Quality Priority:
  Model: small/medium | Threads: 4 | Timestamps: On
```
