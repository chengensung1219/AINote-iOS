"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.reviewAnswer = exports.summarizeTranscript = exports.getAssemblyRealtimeToken = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const generative_ai_1 = require("@google/generative-ai");
const REGION = process.env.FIREBASE_REGION ?? 'us-central1';
const assemblySecret = (0, params_1.defineSecret)('ASSEMBLYAI_API_KEY');
const geminiSecret = (0, params_1.defineSecret)('GEMINI_API_KEY');
const genAI = () => {
    const key = geminiSecret.value();
    return key ? new generative_ai_1.GoogleGenerativeAI(key) : null;
};
function ensurePost(req, res) {
    if (req.method !== 'POST') {
        res.set('Allow', 'POST').status(405).json({ error: 'Only POST allowed.' });
        return false;
    }
    return true;
}
exports.getAssemblyRealtimeToken = (0, https_1.onRequest)({
    region: REGION,
    memory: '256MiB',
    timeoutSeconds: 15,
    secrets: [assemblySecret],
}, async (req, res) => {
    if (!ensurePost(req, res)) {
        return;
    }
    const assemblyKey = assemblySecret.value()?.trim();
    if (!assemblyKey) {
        res.status(500).json({ error: 'Server missing AssemblyAI API key.' });
        return;
    }
    // Universal Streaming API: Use the streaming endpoint
    // Based on AssemblyAI docs, the endpoint is wss://streaming.assemblyai.com/v3/ws
    // The API key is sent in the Authorization header
    try {
        res.json({
            websocket_url: 'wss://streaming.assemblyai.com/v3/ws?sample_rate=16000&format_turns=true',
            sample_rate: 16000,
            api_key: assemblyKey, // Return API key for client to use in Authorization header
        });
    }
    catch (error) {
        console.error('AssemblyAI setup failed:', error);
        const message = error instanceof Error ? error.message : 'Failed to setup streaming.';
        res.status(500).json({ error: message });
    }
});
exports.summarizeTranscript = (0, https_1.onRequest)({
    region: REGION,
    memory: '512MiB',
    timeoutSeconds: 30,
    secrets: [geminiSecret],
}, async (req, res) => {
    if (!ensurePost(req, res)) {
        return;
    }
    const transcript = String(req.body?.transcript ?? '').trim();
    if (!transcript) {
        res.status(400).json({ error: 'transcript is required.' });
        return;
    }
    try {
        const summary = await summarizeWithGemini(transcript);
        res.json({ summary });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to summarize.';
        res.status(500).json({ error: message });
    }
});
exports.reviewAnswer = (0, https_1.onRequest)({
    region: REGION,
    memory: '512MiB',
    timeoutSeconds: 30,
    secrets: [geminiSecret],
}, async (req, res) => {
    if (!ensurePost(req, res)) {
        return;
    }
    const transcript = String(req.body?.transcript ?? '').trim();
    const question = String(req.body?.question ?? '').trim();
    if (!transcript || !question) {
        res.status(400).json({ error: 'transcript and question are required.' });
        return;
    }
    try {
        const result = await reviewWithGemini(question, transcript);
        res.json(result);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to review.';
        res.status(500).json({ error: message });
    }
});
async function summarizeWithGemini(transcript) {
    const client = genAI();
    if (!client) {
        throw new Error('Gemini client is not configured.');
    }
    // Use gemini-2.5-flash as suggested
    const model = client.getGenerativeModel({ model: 'gemini-2.5-flash' });
    const prompt = [
        'Create a concise summary (3 bullet points) with key takeaways and action items.',
        'Keep each bullet under 20 words.',
        '',
        'Transcript:',
        transcript,
    ].join('\n');
    const response = await model.generateContent(prompt);
    return response.response.text().trim();
}
async function reviewWithGemini(question, transcript) {
    const client = genAI();
    if (!client) {
        throw new Error('Gemini client is not configured.');
    }
    const model = client.getGenerativeModel({ model: 'gemini-2.5-flash' });
    const prompt = [
        `Question: ${question}`,
        `Transcript: ${transcript}`,
        '',
        'Please evaluate if the transcript provides a sufficient answer to the question.',
        'Provide a short review (max 50 words) and a score from 1 to 10.',
        'Return the result in JSON format with "review" and "score" keys.',
        'Do not use markdown code blocks.'
    ].join('\n');
    const response = await model.generateContent(prompt);
    const text = response.response.text().trim();
    // Simple cleanup to handle potential markdown backticks
    const jsonStr = text.replace(/^```json\n|\n```$/g, '').replace(/^```\n|\n```$/g, '');
    try {
        return JSON.parse(jsonStr);
    }
    catch (e) {
        // Fallback if JSON parsing fails
        return {
            review: text,
            score: 0
        };
    }
}
//# sourceMappingURL=index.js.map