import 'package:flutter/material.dart';

class MessagesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
      ),
      body: ListView(
        children: <Widget>[
          Container(
            color: Theme.of(context).colorScheme.primary,
            child: ListTile(
              title: Text('Announcements'),
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.primary,
            child: ListTile(
              title: Text('Files'),
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.primary,
            child: ListTile(
              title: Text('Trip Updates'),
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.primary,
            child: ListTile(
              title: Text('Load Board'),
            ),
          ),
          // Weigh Station Status
          Container(
            color: Theme.of(context).colorScheme.primary,
            child: ListTile(
              title: Text('Weigh Station Status'),
            ),
          ),
        ],
      ),
    );
  }
}