{{flutter_js}}
{{flutter_build_config}}

// Serve CanvasKit from this site instead of www.gstatic.com. The service
// worker only caches same-origin files, so the CDN copy would keep the app
// from starting offline. Same effect as `flutter build web
// --no-web-resources-cdn`, without having to remember the flag.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
