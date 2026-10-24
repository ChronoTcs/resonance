#include "discord_rpc_manager.h"

#include <iostream>
#include <variant>

#if __has_include(<discordpp/discordpp.h>)
#define HAS_DISCORD_SDK 1
#define DISCORDPP_IMPLEMENTATION
#include <discordpp/discordpp.h>
#else
#define HAS_DISCORD_SDK 0
#endif

class DiscordRpcManager::Impl {
 public:
  Impl() = default;
  ~Impl() { Dispose(); }

#if HAS_DISCORD_SDK
  std::shared_ptr<discordpp::Client> client_{nullptr};
#endif
  bool is_initialized_{false};

  bool Initialize(const std::string& app_id) {
#if HAS_DISCORD_SDK
    try {
      if (!client_) {
        client_ = std::make_shared<discordpp::Client>();
      }
      uint64_t id = 0;
      if (!app_id.empty()) {
        id = std::stoull(app_id);
      }
      client_->SetApplicationId(id);
      is_initialized_ = true;
      return true;
    } catch (const std::exception& e) {
      std::cerr << "[DiscordRpcManager] Init error: " << e.what() << std::endl;
      return false;
    }
#else
    std::cout << "[DiscordRpcManager] Discord Social SDK headers not present. Running in fallback mode." << std::endl;
    is_initialized_ = true;
    return true;
#endif
  }

  bool UpdatePresence(const flutter::EncodableMap& data) {
    if (!is_initialized_) return false;

#if HAS_DISCORD_SDK
    if (!client_) return false;
    try {
      discordpp::Activity activity;
      std::string app_name = "Resonance";
      auto it_name = data.find(flutter::EncodableValue("name"));
      if (it_name != data.end() && std::holds_alternative<std::string>(it_name->second)) {
        app_name = std::get<std::string>(it_name->second);
      }
      activity.SetName(app_name);
      activity.SetType(discordpp::ActivityTypes::Listening);

      auto it_details = data.find(flutter::EncodableValue("details"));
      if (it_details != data.end() && std::holds_alternative<std::string>(it_details->second)) {
        activity.SetDetails(std::get<std::string>(it_details->second));
      }

      auto it_state = data.find(flutter::EncodableValue("state"));
      if (it_state != data.end() && std::holds_alternative<std::string>(it_state->second)) {
        activity.SetState(std::get<std::string>(it_state->second));
      }

      // Timestamps
      discordpp::ActivityTimestamps timestamps;
      bool has_timestamps = false;
      auto it_start = data.find(flutter::EncodableValue("startTimestamp"));
      if (it_start != data.end()) {
        if (std::holds_alternative<int64_t>(it_start->second)) {
          timestamps.SetStart(std::get<int64_t>(it_start->second));
          has_timestamps = true;
        } else if (std::holds_alternative<int32_t>(it_start->second)) {
          timestamps.SetStart(std::get<int32_t>(it_start->second));
          has_timestamps = true;
        }
      }
      auto it_end = data.find(flutter::EncodableValue("endTimestamp"));
      if (it_end != data.end()) {
        if (std::holds_alternative<int64_t>(it_end->second)) {
          timestamps.SetEnd(std::get<int64_t>(it_end->second));
          has_timestamps = true;
        } else if (std::holds_alternative<int32_t>(it_end->second)) {
          timestamps.SetEnd(std::get<int32_t>(it_end->second));
          has_timestamps = true;
        }
      }
      if (has_timestamps) {
        activity.SetTimestamps(timestamps);
      }

      // Assets
      discordpp::ActivityAssets assets;
      bool has_assets = false;
      auto it_large_img = data.find(flutter::EncodableValue("largeImage"));
      if (it_large_img != data.end() && std::holds_alternative<std::string>(it_large_img->second)) {
        assets.SetLargeImage(std::get<std::string>(it_large_img->second));
        has_assets = true;
      }
      auto it_large_txt = data.find(flutter::EncodableValue("largeText"));
      if (it_large_txt != data.end() && std::holds_alternative<std::string>(it_large_txt->second)) {
        assets.SetLargeText(std::get<std::string>(it_large_txt->second));
        has_assets = true;
      }
      auto it_small_img = data.find(flutter::EncodableValue("smallImage"));
      if (it_small_img != data.end() && std::holds_alternative<std::string>(it_small_img->second)) {
        const auto& s = std::get<std::string>(it_small_img->second);
        if (!s.empty()) {
          assets.SetSmallImage(s);
          has_assets = true;
        }
      }
      auto it_small_txt = data.find(flutter::EncodableValue("smallText"));
      if (it_small_txt != data.end() && std::holds_alternative<std::string>(it_small_txt->second)) {
        const auto& s = std::get<std::string>(it_small_txt->second);
        if (!s.empty()) {
          assets.SetSmallText(s);
          has_assets = true;
        }
      }
      if (has_assets) {
        activity.SetAssets(assets);
      }

      // Interactive action buttons (Listen Along, Play on Resonance)
      auto get_str = [&](const std::string& key) -> std::optional<std::string> {
        auto it = data.find(flutter::EncodableValue(key));
        if (it != data.end() && std::holds_alternative<std::string>(it->second))
          return std::get<std::string>(it->second);
        return std::nullopt;
      };
      auto b1_lbl = get_str("button1Label");
      auto b1_url = get_str("button1Url");
      auto b2_lbl = get_str("button2Label");
      auto b2_url = get_str("button2Url");
      if (b1_lbl && b1_url && !b1_lbl->empty() && !b1_url->empty()) {
        discordpp::ActivityButton b1;
        b1.SetLabel(*b1_lbl);
        b1.SetUrl(*b1_url);
        activity.AddButton(b1);
      }
      if (b2_lbl && b2_url && !b2_lbl->empty() && !b2_url->empty()) {
        discordpp::ActivityButton b2;
        b2.SetLabel(*b2_lbl);
        b2.SetUrl(*b2_url);
        activity.AddButton(b2);
      }

      client_->UpdateRichPresence(activity, [](const discordpp::ClientResult& result) {
        if (!result.Successful()) {
          std::cerr << "[DiscordRpcManager] UpdateRichPresence unconfirmed" << std::endl;
        }
      });
      return true;
    } catch (const std::exception& e) {
      std::cerr << "[DiscordRpcManager] UpdatePresence exception: " << e.what() << std::endl;
      return false;
    }
#else
    return true;
#endif
  }

  bool ClearPresence() {
    if (!is_initialized_) return false;
#if HAS_DISCORD_SDK
    if (!client_) return false;
    client_->ClearRichPresence();
#endif
    return true;
  }

  void Dispose() {
    ClearPresence();
#if HAS_DISCORD_SDK
    client_ = nullptr;
#endif
    is_initialized_ = false;
  }

  void Tick() {
#if HAS_DISCORD_SDK
    if (is_initialized_) {
      discordpp::RunCallbacks();
    }
#endif
  }
};

DiscordRpcManager& DiscordRpcManager::GetInstance() {
  static DiscordRpcManager instance;
  return instance;
}

DiscordRpcManager::DiscordRpcManager() : impl_(std::make_unique<Impl>()) {}
DiscordRpcManager::~DiscordRpcManager() = default;

bool DiscordRpcManager::Initialize(const std::string& app_id) {
  return impl_->Initialize(app_id);
}

bool DiscordRpcManager::UpdatePresence(const flutter::EncodableMap& data) {
  return impl_->UpdatePresence(data);
}

bool DiscordRpcManager::ClearPresence() {
  return impl_->ClearPresence();
}

void DiscordRpcManager::Dispose() {
  impl_->Dispose();
}

void DiscordRpcManager::Tick() {
  impl_->Tick();
}
