#ifndef RUNNER_DISCORD_RPC_MANAGER_H_
#define RUNNER_DISCORD_RPC_MANAGER_H_

#include <flutter/encodable_value.h>
#include <memory>
#include <string>

class DiscordRpcManager {
 public:
  static DiscordRpcManager& GetInstance();

  bool Initialize(const std::string& app_id);
  bool UpdatePresence(const flutter::EncodableMap& data);
  bool ClearPresence();
  void Dispose();
  void Tick();

 private:
  DiscordRpcManager();
  ~DiscordRpcManager();

  DiscordRpcManager(const DiscordRpcManager&) = delete;
  DiscordRpcManager& operator=(const DiscordRpcManager&) = delete;

  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_DISCORD_RPC_MANAGER_H_
