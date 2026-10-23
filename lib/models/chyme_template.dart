/// The endpoints people actually point an assistant at.
///
/// Typing an API base is the step where this gets abandoned. It is one line of
/// text, it has to be exactly right — the version path, the trailing slash, the
/// `/v1` — and nothing on the screen says what the right answer is. These are
/// the four that come up, plus the one that runs on your own machine, so the
/// common case is a tap and the uncommon case is still a text field.
///
/// No model ids are baked in. A model list is the endpoint's to give and it
/// changes without asking; the app fetches `/models` from whatever base is set
/// and offers what comes back, which is the only version of this that does not
/// go stale.
enum ChymeTemplate {
  groq(
    'Groq',
    'Fast, and generous on the free tier. Runs open models.',
    'https://api.groq.com/openai/v1',
    'https://console.groq.com/keys',
  ),
  openRouter(
    'OpenRouter',
    'One key, and almost every model there is — including free ones.',
    'https://openrouter.ai/api/v1',
    'https://openrouter.ai/keys',
  ),
  aiStudio(
    'Google AI Studio',
    'Gemini, through Google\'s OpenAI-compatible endpoint.',
    'https://generativelanguage.googleapis.com/v1beta/openai',
    'https://aistudio.google.com/apikey',
  ),
  openAi(
    'OpenAI',
    'The original, and the endpoint everything else copies.',
    'https://api.openai.com/v1',
    'https://platform.openai.com/api-keys',
  ),
  local(
    'On this machine',
    'Ollama, or anything else listening on localhost. No key, no account, and '
        'nothing leaves the device.',
    'http://localhost:11434/v1',
    null,
  ),
  custom(
    'Something else',
    'Any endpoint that speaks the OpenAI chat API.',
    '',
    null,
  );

  const ChymeTemplate(this.label, this.description, this.endpoint, this.keyUrl);

  final String label;
  final String description;

  /// The API base, ready to paste.
  final String endpoint;

  /// Where a key comes from, or null when there is nothing to get.
  final String? keyUrl;

  /// Whether this is an endpoint somebody has to type in.
  bool get needsTyping => endpoint.isEmpty;

  /// The template a saved endpoint came from, or [custom] when it is not one of
  /// these — which is what makes the row able to say where you are without
  /// storing it separately.
  static ChymeTemplate forEndpoint(String endpoint) {
    final String trimmed = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    for (final ChymeTemplate template in values) {
      if (template.endpoint.isEmpty) continue;
      if (template.endpoint.replaceAll(RegExp(r'/+$'), '') == trimmed) {
        return template;
      }
    }
    return ChymeTemplate.custom;
  }
}
