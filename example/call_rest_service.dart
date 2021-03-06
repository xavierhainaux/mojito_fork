// Copyright (c) 2015, The Mojito project authors.
// Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by
// a BSD 2-Clause License that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mojito/mojito.dart';
import 'package:shelf/shelf.dart';

const String nomeAKUrl = 'https://query.yahooapis.com/v1/public/yql?'
    'q=select%20*%20from%20weather.forecast%20where%20woeid%20in%20'
    '(select%20woeid%20from%20geo.places(1)%20'
    'where%20text%3D%22nome%2C%20ak%22)'
    '&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys';

const String greenlandUrl = 'https://query.yahooapis.com/v1/public/yql?'
    'q=select%20*%20from%20weather.forecast%20where%20woeid%20in%20'
    '(select%20woeid%20from%20geo.places(1)%20where%20text%3D%22'
    'greenland%22)&format=json&'
    'env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys';

Logger _log = new Logger('example');

main() {
  final app = init(isDevMode: () => true);

  app.router
    ..get('weather', () async {
      /*
       * Makes two simultaneous requests to the weather service and then sends
       * both results back to the caller
       */
      final nomeFuture = http.get(nomeAKUrl);
      final greenlandFuture = http.get(greenlandUrl);

      final result = await Future.wait([nomeFuture, greenlandFuture]);
      final bodies =
          result.map((http.Response r) => JSON.decode(r.body)).toList();
      return {"nome": bodies[0], "greenland": bodies[1]};
    })
    ..get('streamed', () {
      /*
       * Here we make several simultaneous requests to the weather service
       * and stream back the results as they come. We add a delay and some new
       * lines to make it easier to observe the streaming. Note the newlines
       * seem to help dart:io to decide to send the events as they come
       */
      final sc = new StreamController<String>();

      int delay = 0;

      addResponse(http.Response r) async {
        await new Future.delayed(new Duration(seconds: delay++));
        sc
          ..add(new DateTime.now().toIso8601String())
          ..add('\n')
          ..add(r.body)
          ..add('\n\n\n');
      }

      final responseFutures = [nomeAKUrl, greenlandUrl, nomeAKUrl, greenlandUrl]
          .map((url) => http.get(nomeAKUrl).then(addResponse));

      Future.wait(responseFutures).then((_) {
        return sc.close();
      });

      final os = sc.stream.transform(UTF8.encoder);

      // Note: the shelf.io.buffer_output context parameter must be set false
      // to trigger the streaming of the results.
      return new Response.ok(os, context: {"shelf.io.buffer_output": false});
    });

  app.start();
}
