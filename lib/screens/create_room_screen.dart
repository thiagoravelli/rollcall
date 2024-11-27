// File: lib/screens/create_room_screen.dart
// ignore_for_file: deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:algolia/algolia.dart';
import '../services/database_helper.dart';

class CreateRoomScreen extends StatefulWidget {
  final String loggedInUserEmail;
  final String loggedInUserName;

  const CreateRoomScreen({
    Key? key,
    required this.loggedInUserEmail,
    required this.loggedInUserName,
  }) : super(key: key);

  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _addressController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int? _selectedPlayerSlots; // Start as null
  int _selectedWaitlistSlots = 0; // Default is 0

  // New variables for game selection
  final TextEditingController _gameSearchController = TextEditingController();
  List<AlgoliaObjectSnapshot> _searchResults = [];
  bool _isLoading = false;
  bool _isFetchingGameDetails = false;
  Map<String, dynamic>? _selectedGame;
  String? _thumbnailUrl;
  int? _minPlayers;
  int? _maxPlayers;
  int? _playingTime;

  // Initialize Algolia
  final Algolia _algoliaApp = const Algolia.init(
    applicationId: 'OE434A77T6', // Replace with your Algolia App ID
    apiKey: 'a3f2517d38cf61fc9f5ff168aaca37de', // Replace with your Algolia Search-Only API Key
  );

  // Handle room creation
  void _handleCreateRoom() async {
    if (_selectedGame == null) {
      _showErrorDialog('Por favor, selecione um jogo.');
      return;
    }

    final address = _addressController.text.trim();
    final selectedDate = _selectedDate;
    final selectedTime = _selectedTime;

    // Validate required fields
    if (selectedDate == null || selectedTime == null || address.isEmpty) {
      _showErrorDialog('Por favor, preencha todos os campos obrigatórios.');
      return;
    }

    // Combine date and time into a full DateTime for storage
    final DateTime fullDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final room = {
      'gameName': _selectedGame!['name'],
      'gameId': _selectedGame!['id'],
      'thumbnailUrl': _thumbnailUrl,
      'minPlayers': _minPlayers,
      'maxPlayers': _maxPlayers,
      'playingTime': _playingTime,
      'dateTime': fullDateTime.toIso8601String(),
      'address': address,
      'playerSlots': _selectedPlayerSlots,
      'waitlistSlots': _selectedWaitlistSlots,
      'creatorName': widget.loggedInUserName,
    };

    try {
      // Insert the room into the database
      final roomId = await DatabaseHelper.instance.insertRoom(room);

      // Add the creator as a participant
      int userId = await _getLoggedInUserId();
      await DatabaseHelper.instance.addParticipant(roomId, userId);

      // Show a confirmation dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Sala Criada'),
            content: Text(
                'A sala "${_selectedGame!['name']}" foi criada com sucesso para ${fullDateTime.day}/${fullDateTime.month}/${fullDateTime.year} às ${fullDateTime.hour}:${fullDateTime.minute.toString().padLeft(2, '0')}.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Return to the previous screen
                },
                child: const Text('Ok'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showErrorDialog('Erro ao criar a sala. Tente novamente.');
    }
  }

  Future<int> _getLoggedInUserId() async {
    final db = await DatabaseHelper.instance.database;
    final result =
        await db.query('users', where: 'email = ?', whereArgs: [widget.loggedInUserEmail]);
    return result.isNotEmpty ? result.first['id'] as int : 0;
  }

  // Show an error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Erro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  // Methods to pick date and time
  Future<void> _pickDate(BuildContext context) async {
    final currentDate = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: currentDate,
      lastDate: DateTime(currentDate.year + 2),
      helpText: 'Selecione a data do jogo',
      cancelText: 'Cancelar',
      confirmText: 'Ok',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay initialTime = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Selecione o horário do jogo',
      cancelText: 'Cancelar',
      confirmText: 'Ok',
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Search games using Algolia
  Future<void> _searchGames(String query) async {
    setState(() {
      _isLoading = true;
    });

    AlgoliaQuery algoliaQuery =
        _algoliaApp.instance.index('filtered_boardgames_ranks').query(query);
    AlgoliaQuerySnapshot snapshot = await algoliaQuery.getObjects();

    setState(() {
      _searchResults = snapshot.hits;
      _isLoading = false;
    });
  }

  // Fetch game details from BoardGameGeek XML API2
  Future<void> _fetchGameDetails(String gameId) async {
    final url = 'https://www.boardgamegeek.com/xmlapi2/thing?id=$gameId';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final item = document.findAllElements('item').first;

        setState(() {
          _minPlayers = item.findElements('minplayers').isNotEmpty
              ? int.tryParse(item.findElements('minplayers').first.getAttribute('value') ?? '')
              : null;
          _maxPlayers = item.findElements('maxplayers').isNotEmpty
              ? int.tryParse(item.findElements('maxplayers').first.getAttribute('value') ?? '')
              : null;
          _playingTime = item.findElements('playingtime').isNotEmpty
              ? int.tryParse(item.findElements('playingtime').first.getAttribute('value') ?? '')
              : null;
          _thumbnailUrl = item.findElements('thumbnail').isNotEmpty
              ? item.findElements('thumbnail').first.text
              : null;
          // Update selected player slots based on min and max players
          _selectedPlayerSlots = _minPlayers ?? 2;
        });
      } else {
        _showErrorDialog('Erro ao obter detalhes do jogo.');
      }
    } catch (e) {
      _showErrorDialog('Erro ao obter detalhes do jogo.');
    } finally {
      setState(() {
        _isFetchingGameDetails = false;
      });
    }
  }

  // Dispose controllers to free resources
  @override
  void dispose() {
    _addressController.dispose();
    _gameSearchController.dispose();
    super.dispose();
  }

  // Build the UI for the Create Room screen
  @override
  Widget build(BuildContext context) {
    // Determine if the game is selected
    bool isGameSelected = _selectedGame != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Sala'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game Search Field
            TextFormField(
              controller: _gameSearchController,
              decoration: const InputDecoration(
                labelText: 'Buscar jogo',
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _searchGames(value);
                } else {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            if (_isLoading) const LinearProgressIndicator(),
            if (_searchResults.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index].data;
                    return ListTile(
                      title: Text(result['name']),
                      onTap: () async {
                        setState(() {
                          _selectedGame = result;
                          _searchResults = [];
                          _gameSearchController.text = result['name'];
                          _isFetchingGameDetails = true;
                          // Reset the player slots
                          _selectedPlayerSlots = null;
                          _minPlayers = null;
                          _maxPlayers = null;
                          _playingTime = null;
                          _thumbnailUrl = null;
                        });
                        await _fetchGameDetails(result['id']);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // Display selected game details
            if (_isFetchingGameDetails)
              const Center(child: CircularProgressIndicator())
            else if (_selectedGame != null) ...[
              Text(
                'Jogo Selecionado: ${_selectedGame!['name']}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_thumbnailUrl != null)
                Image.network(_thumbnailUrl!, height: 150),
              const SizedBox(height: 8),
              if (_minPlayers != null && _maxPlayers != null)
                Text('Jogadores: $_minPlayers - $_maxPlayers'),
              if (_playingTime != null)
                Text('Tempo de jogo: $_playingTime minutos'),
            ],
            const SizedBox(height: 16),

            // Number of player slots
            DropdownButtonFormField<int>(
              value: _selectedPlayerSlots,
              decoration:
                  const InputDecoration(labelText: 'Número de vagas de jogadores'),
              items: isGameSelected && _minPlayers != null && _maxPlayers != null
                  ? List.generate(
                      (_maxPlayers! - _minPlayers! + 1),
                      (index) {
                        int value = _minPlayers! + index;
                        return DropdownMenuItem(
                            value: value, child: Text('$value jogadores'));
                      },
                    )
                  : [],
              onChanged: isGameSelected
                  ? (value) {
                      setState(() {
                        _selectedPlayerSlots = value!;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 16),

            // Date selection
            Row(
              children: [
                Expanded(
                  child: Text(_selectedDate == null
                      ? 'Nenhuma data selecionada'
                      : 'Data: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _pickDate(context);
                  },
                  child: const Text('Selecione a data'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time selection
            Row(
              children: [
                Expanded(
                  child: Text(_selectedTime == null
                      ? 'Nenhum horário selecionado'
                      : 'Horário: ${_selectedTime!.format(context)}'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _pickTime(context);
                  },
                  child: const Text('Selecione o horário'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Address Field
            TextFormField(
              controller: _addressController,
              decoration:
                  const InputDecoration(labelText: 'Endereço (máx. 64 caracteres)'),
              maxLength: 64,
            ),
            const SizedBox(height: 16),

            // Number of waitlist slots
            DropdownButtonFormField<int>(
              value: _selectedWaitlistSlots,
              decoration:
                  const InputDecoration(labelText: 'Número de vagas na lista de espera'),
              items: List.generate(
                6,
                (index) => DropdownMenuItem(value: index, child: Text('$index vagas')),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedWaitlistSlots = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Room creator (automatically filled)
            Text(
              'Autor da sala: ${widget.loggedInUserName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            // Spacing
            const SizedBox(height: 32),

            // Buttons (Criar and Voltar)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: isGameSelected && _selectedPlayerSlots != null
                      ? _handleCreateRoom
                      : null,
                  child: const Text('Criar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
