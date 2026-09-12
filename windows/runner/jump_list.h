#ifndef RUNNER_JUMP_LIST_H_
#define RUNNER_JUMP_LIST_H_

#include <string>
#include <vector>

struct JumpListItem {
  std::wstring title;
  std::wstring artist;
  std::wstring track_id;
};

class JumpListManager {
 public:
  static bool UpdateJumpList(
      const std::vector<JumpListItem>& recent_tracks,
      const std::vector<JumpListItem>& quick_picks);
  static void ClearJumpList();
};

#endif  // RUNNER_JUMP_LIST_H_
