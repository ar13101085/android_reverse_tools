import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConsolePanel extends StatefulWidget {
  final String output;
  final VoidCallback onClear;

  ConsolePanel({required this.output, required this.onClear});

  @override
  _ConsolePanelState createState() => _ConsolePanelState();
}

class _ConsolePanelState extends State<ConsolePanel> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void didUpdateWidget(ConsolePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.output != oldWidget.output && _autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    if (widget.output.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: widget.output));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Console output copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScroll = !_autoScroll;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            color: Colors.grey[800],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text(
                    'Console Output',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_top,
                        color: _autoScroll ? Colors.green : Colors.white,
                        size: 20,
                      ),
                      onPressed: _toggleAutoScroll,
                      tooltip: _autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.white, size: 20),
                      onPressed: _copyToClipboard,
                      tooltip: 'Copy all output',
                    ),
                    IconButton(
                      icon: Icon(Icons.clear, color: Colors.white),
                      onPressed: widget.onClear,
                      tooltip: 'Clear console',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SelectableText(
                        widget.output,
                        style: TextStyle(
                          color: Colors.green[300],
                          fontFamily: 'Courier',
                          fontSize: 12,
                          height: 1.4,
                        ),
                        contextMenuBuilder: (context, editableTextState) {
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: [
                              ContextMenuButtonItem(
                                onPressed: () {
                                  editableTextState.copySelection(SelectionChangedCause.toolbar);
                                },
                                type: ContextMenuButtonType.copy,
                              ),
                              ContextMenuButtonItem(
                                onPressed: () {
                                  editableTextState.selectAll(SelectionChangedCause.toolbar);
                                },
                                type: ContextMenuButtonType.selectAll,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.output.isEmpty)
                    Center(
                      child: Text(
                        'Console output will appear here...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}