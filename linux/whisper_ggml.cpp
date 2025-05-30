#include "whisper.cpp/whisper.h"

#define DR_WAV_IMPLEMENTATION
#include "whisper.cpp/examples/dr_wav.h"

#include <cstdio>
#include <string>
#include <thread>
#include <vector>
#include <cmath>
#include <iostream>
#include <stdio.h>
#include "json/json.hpp"

using json = nlohmann::json;

char *jsonToChar(json jsonData) noexcept
{
    std::string result = jsonData.dump();
    char *ch = new char[result.size() + 1];
    strcpy(ch, result.c_str());
    return ch;
}

struct whisper_params
{
    int32_t seed = -1; // RNG seed, not used currently
    int32_t n_threads = std::min(4, (int32_t)std::thread::hardware_concurrency());

    int32_t n_processors = 1;
    int32_t offset_t_ms = 0;
    int32_t offset_n = 0;
    int32_t duration_ms = 0;
    int32_t max_context = -1;
    int32_t max_len = 0;
    int32_t best_of = 5;
    int32_t beam_size = -1;

    float word_thold = 0.01f;
    float entropy_thold = 2.40f;
    float logprob_thold = -1.00f;

    bool verbose = false;
    bool print_special_tokens = false;
    bool speed_up = false;
    bool translate = false;
    bool diarize = false;
    bool no_fallback = false;
    bool output_txt = false;
    bool output_vtt = false;
    bool output_srt = false;
    bool output_wts = false;
    bool output_csv = false;
    bool print_colors = false;
    bool print_progress = false;
    bool no_timestamps = false;

    std::string language = "en";
    std::string model = "models/ggml-base.en.bin";
    std::string fname_inp = "samples/jfk.wav";
    std::string output_dir = ".";
    std::string prompt = "";

    std::vector<std::string> fname_out = {};
};

bool read_wav(const std::string &fname, std::vector<float> &pcmf32, std::vector<std::vector<float>> &pcmf32s, bool stereo)
{
    drwav wav;
    std::vector<uint8_t> wav_data; // used for pipe input from stdin

    if (fname == "-")
    {
        {
            uint8_t buf[1024];
            while (true)
            {
                const size_t n = fread(buf, 1, sizeof(buf), stdin);
                if (n == 0)
                {
                    break;
                }
                wav_data.insert(wav_data.end(), buf, buf + n);
            }
        }

        if (drwav_init_memory(&wav, wav_data.data(), wav_data.size(), nullptr) == false)
        {
            fprintf(stderr, "error: failed to open WAV file from stdin\n");
            return false;
        }

        fprintf(stderr, "%s: read %zu bytes from stdin\n", __func__, wav_data.size());
    }
    else if (drwav_init_file(&wav, fname.c_str(), nullptr) == false)
    {
        fprintf(stderr, "error: failed to open '%s' as WAV file\n", fname.c_str());
        return false;
    }

    if (wav.channels != 1 && wav.channels != 2)
    {
        fprintf(stderr, "%s: WAV file '%s' must be mono or stereo\n", __func__, fname.c_str());
        return false;
    }

    if (stereo && wav.channels != 2)
    {
        fprintf(stderr, "%s: WAV file '%s' must be stereo for diarization\n", __func__, fname.c_str());
        return false;
    }

    if (wav.sampleRate != WHISPER_SAMPLE_RATE)
    {
        fprintf(stderr, "%s: WAV file '%s' must be %i kHz\n", __func__, fname.c_str(), WHISPER_SAMPLE_RATE / 1000);
        return false;
    }

    if (wav.bitsPerSample != 16)
    {
        fprintf(stderr, "%s: WAV file '%s' must be 16-bit\n", __func__, fname.c_str());
        return false;
    }

    const uint64_t n = wav_data.empty() ? wav.totalPCMFrameCount : wav_data.size() / (wav.channels * wav.bitsPerSample / 8);

    std::vector<int16_t> pcm16;
    pcm16.resize(n * wav.channels);
    drwav_read_pcm_frames_s16(&wav, n, pcm16.data());
    drwav_uninit(&wav);

    // convert to mono, float
    pcmf32.resize(n);
    if (wav.channels == 1)
    {
        for (uint64_t i = 0; i < n; i++)
        {
            pcmf32[i] = float(pcm16[i]) / 32768.0f;
        }
    }
    else
    {
        for (uint64_t i = 0; i < n; i++)
        {
            pcmf32[i] = float(pcm16[2 * i] + pcm16[2 * i + 1]) / 65536.0f;
        }
    }

    if (stereo)
    {
        // convert to stereo, float
        pcmf32s.resize(2);

        pcmf32s[0].resize(n);
        pcmf32s[1].resize(n);
        for (uint64_t i = 0; i < n; i++)
        {
            pcmf32s[0][i] = float(pcm16[2 * i]) / 32768.0f;
            pcmf32s[1][i] = float(pcm16[2 * i + 1]) / 32768.0f;
        }
    }

    return true;
}

// FFI Symbol Export Strategy
// 
// Architecture Decision: Single exported function with C linkage
// - Reason: Dart FFI requires C linkage for symbol resolution
// - Visibility: Explicit export despite hidden default visibility
// - Justification: Minimizes symbol pollution while ensuring FFI accessibility

extern "C" __attribute__((visibility("default")))
char* request(char* body)
{
    json requestJson;
    json responseJson;

    try {
        // Debug: Log the incoming request to file
        FILE* debug_log = fopen("/tmp/whisper_debug.log", "a");
        if (debug_log) {
            fprintf(debug_log, "DEBUG: request() called with body: %s\n", body);
            fflush(debug_log);
        }
        
        requestJson = json::parse(body);
        std::string action = requestJson["@type"];
        
        if (debug_log) {
            fprintf(debug_log, "DEBUG: action = %s\n", action.c_str());
            fflush(debug_log);
        }
        
        if (action == "getVersion") {
            responseJson["@type"] = "getVersion";
            responseJson["version"] = "1.0.0";
            if (debug_log) {
                fprintf(debug_log, "DEBUG: getVersion completed\n");
                fflush(debug_log);
            }
        } else if (action == "getTextFromWavFile") {
            if (debug_log) {
                fprintf(debug_log, "DEBUG: Starting transcribe action\n");
                fflush(debug_log);
            }
            // Initialize whisper
            std::string modelPath = requestJson["model"];
            if (debug_log) {
                fprintf(debug_log, "DEBUG: Model path: %s\n", modelPath.c_str());
                fflush(debug_log);
            }
            
            if (debug_log) {
                fprintf(debug_log, "DEBUG: About to call whisper_init_from_file\n");
                fflush(debug_log);
            }
            
            struct whisper_context *ctx = whisper_init_from_file(modelPath.c_str());
            
            if (ctx == nullptr) {
                if (debug_log) {
                    fprintf(debug_log, "DEBUG: Failed to initialize whisper model\n");
                    fflush(debug_log);
                }
                responseJson["error"] = "Failed to initialize model";
                return jsonToChar(responseJson);
            }
            
            if (debug_log) {
                fprintf(debug_log, "DEBUG: Whisper context initialized successfully\n");
                fflush(debug_log);
            }

            // Set up parameters
            whisper_params params;
            params.fname_inp = requestJson["audio"];
            params.language = requestJson["language"];
            params.translate = requestJson["is_translate"];
            params.no_timestamps = requestJson["is_no_timestamps"];
            params.n_threads = requestJson["threads"];
            params.print_special_tokens = requestJson["is_special_tokens"];

            if (debug_log) {
                fprintf(debug_log, "DEBUG: Audio file path: %s\n", params.fname_inp.c_str());
                fflush(debug_log);
            }

            // Read audio
            std::vector<float> pcmf32;
            std::vector<std::vector<float>> pcmf32s;
            
            if (debug_log) {
                fprintf(debug_log, "DEBUG: About to read audio file\n");
                fflush(debug_log);
            }
            
            if (!read_wav(params.fname_inp, pcmf32, pcmf32s, params.diarize)) {
                if (debug_log) {
                    fprintf(debug_log, "DEBUG: Failed to read audio file\n");
                    fflush(debug_log);
                }
                whisper_free(ctx);
                responseJson["error"] = "Failed to read audio file";
                return jsonToChar(responseJson);
            }

            if (debug_log) {
                fprintf(debug_log, "DEBUG: Audio file read successfully, samples: %zu\n", pcmf32.size());
                fflush(debug_log);
            }

            if (debug_log) {
                fprintf(debug_log, "DEBUG: Setting up whisper inference parameters\n");
                fflush(debug_log);
            }
            
            // Run inference
            whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
            
            wparams.print_realtime   = false;
            wparams.print_progress   = params.print_progress;
            wparams.print_timestamps = !params.no_timestamps;
            wparams.print_special    = params.print_special_tokens;
            wparams.translate        = params.translate;
            wparams.language         = params.language.c_str();
            wparams.n_threads        = params.n_threads;
            wparams.n_max_text_ctx   = params.max_context >= 0 ? params.max_context : wparams.n_max_text_ctx;
            wparams.offset_ms        = params.offset_t_ms;
            wparams.duration_ms      = params.duration_ms;
            
            wparams.token_timestamps = params.output_wts || params.max_len > 0;
            wparams.thold_pt         = params.word_thold;
            wparams.entropy_thold    = params.entropy_thold;
            wparams.logprob_thold    = params.logprob_thold;
            wparams.max_len          = params.output_wts && params.max_len == 0 ? 60 : params.max_len;

            wparams.speed_up         = params.speed_up;

            wparams.greedy.best_of        = params.best_of;
            wparams.beam_search.beam_size = params.beam_size;

            wparams.prompt_tokens    = nullptr;
            wparams.prompt_n_tokens  = 0;

            if (debug_log) {
                fprintf(debug_log, "DEBUG: About to call whisper_full_parallel\n");
                fflush(debug_log);
            }
            
            if (whisper_full_parallel(ctx, wparams, pcmf32.data(), pcmf32.size(), params.n_processors) != 0) {
                if (debug_log) {
                    fprintf(debug_log, "DEBUG: whisper_full_parallel failed\n");
                    fflush(debug_log);
                }
                whisper_free(ctx);
                responseJson["error"] = "Failed to process audio";
                return jsonToChar(responseJson);
            }

            if (debug_log) {
                fprintf(debug_log, "DEBUG: whisper_full_parallel completed successfully\n");
                fflush(debug_log);
            }

            // Get results
            const int n_segments = whisper_full_n_segments(ctx);
            
            if (debug_log) {
                fprintf(debug_log, "DEBUG: Number of segments: %d\n", n_segments);
                fflush(debug_log);
            }
            
            responseJson["@type"] = "getTextFromWavFile";
            responseJson["text"] = "";
            
            json segments = json::array();
            
            for (int i = 0; i < n_segments; ++i) {
                const char * text = whisper_full_get_segment_text(ctx, i);
                const int64_t t0 = whisper_full_get_segment_t0(ctx, i);
                const int64_t t1 = whisper_full_get_segment_t1(ctx, i);
                
                if (debug_log) {
                    fprintf(debug_log, "DEBUG: Segment %d: '%s'\n", i, text ? text : "null");
                    fflush(debug_log);
                }
                
                if (text) {
                    responseJson["text"] = std::string(responseJson["text"]) + std::string(text);
                }
                
                if (!params.no_timestamps) {
                    json segment;
                    segment["text"] = text ? text : "";
                    segment["start"] = t0 * 10; // Convert to milliseconds
                    segment["end"] = t1 * 10;
                    segments.push_back(segment);
                }
            }
            
            responseJson["segments"] = segments;
            
            if (debug_log) {
                fprintf(debug_log, "DEBUG: Final text: '%s'\n", std::string(responseJson["text"]).c_str());
                fflush(debug_log);
            }
            
            // Clean up
            whisper_free(ctx);
        } else {
            responseJson["error"] = "Unknown action: " + action;
        }
        
        if (debug_log) {
            fclose(debug_log);
        }
    } catch (const std::exception& e) {
        FILE* debug_log = fopen("/tmp/whisper_debug.log", "a");
        if (debug_log) {
            fprintf(debug_log, "DEBUG: Exception caught: %s\n", e.what());
            fflush(debug_log);
            fclose(debug_log);
        }
        responseJson["error"] = std::string("Exception: ") + e.what();
    } catch (...) {
        FILE* debug_log = fopen("/tmp/whisper_debug.log", "a");
        if (debug_log) {
            fprintf(debug_log, "DEBUG: Unknown exception caught\n");
            fflush(debug_log);
            fclose(debug_log);
        }
        responseJson["error"] = "Unknown exception occurred";
    }

    FILE* debug_log = fopen("/tmp/whisper_debug.log", "a");
    if (debug_log) {
        fprintf(debug_log, "DEBUG: Returning response\n");
        fflush(debug_log);
        fclose(debug_log);
    }
    return jsonToChar(responseJson);
}