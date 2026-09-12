#include "jump_list.h"

#include <windows.h>
#include <shobjidl.h>
#include <propkey.h>
#include <propvarutil.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;

static constexpr const wchar_t kAppUserModelID[] = L"com.chronostudio.Resonance";

static ComPtr<IShellLinkW> CreateShellLink(
    const std::wstring& exe_path,
    const std::wstring& title,
    const std::wstring& arguments,
    const std::wstring& description,
    int icon_index = 0) {
  ComPtr<IShellLinkW> link;
  HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&link));
  if (FAILED(hr)) return nullptr;

  link->SetPath(exe_path.c_str());
  link->SetArguments(arguments.c_str());
  if (!description.empty()) {
    link->SetDescription(description.c_str());
  }
  link->SetIconLocation(exe_path.c_str(), icon_index);

  ComPtr<IPropertyStore> prop_store;
  hr = link.As(&prop_store);
  if (SUCCEEDED(hr)) {
    PROPVARIANT pv;
    hr = InitPropVariantFromString(title.c_str(), &pv);
    if (SUCCEEDED(hr)) {
      prop_store->SetValue(PKEY_Title, pv);
      PropVariantClear(&pv);
      prop_store->Commit();
    }
  }
  return link;
}

bool JumpListManager::UpdateJumpList(
    const std::vector<JumpListItem>& recent_tracks,
    const std::vector<JumpListItem>& quick_picks) {
  wchar_t exe_path[MAX_PATH];
  if (GetModuleFileNameW(nullptr, exe_path, MAX_PATH) == 0) {
    return false;
  }

  ComPtr<ICustomDestinationList> dest_list;
  HRESULT hr = CoCreateInstance(CLSID_DestinationList, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dest_list));
  if (FAILED(hr)) return false;

  dest_list->SetAppID(kAppUserModelID);

  UINT min_slots = 0;
  ComPtr<IObjectArray> removed_objects;
  hr = dest_list->BeginList(&min_slots, IID_PPV_ARGS(&removed_objects));
  if (FAILED(hr)) return false;

  // 1. Category: Recently Played
  if (!recent_tracks.empty()) {
    ComPtr<IObjectCollection> recent_collection;
    hr = CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                          CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&recent_collection));
    if (SUCCEEDED(hr)) {
      for (const auto& item : recent_tracks) {
        std::wstring args = L"--play-track=\"" + item.track_id + L"\"";
        auto link = CreateShellLink(exe_path, item.title, args, item.artist, 0);
        if (link) {
          recent_collection->AddObject(link.Get());
        }
      }
      dest_list->AppendCategory(L"Recently Played", recent_collection.Get());
    }
  }

  // 2. Category: Quick Picks
  if (!quick_picks.empty()) {
    ComPtr<IObjectCollection> quick_picks_collection;
    hr = CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                          CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&quick_picks_collection));
    if (SUCCEEDED(hr)) {
      for (const auto& item : quick_picks) {
        std::wstring args = L"--play-track=\"" + item.track_id + L"\"";
        auto link = CreateShellLink(exe_path, item.title, args, item.artist, 0);
        if (link) {
          quick_picks_collection->AddObject(link.Get());
        }
      }
      dest_list->AppendCategory(L"Quick Picks", quick_picks_collection.Get());
    }
  }

  // 3. User Tasks: Play / Pause, Next Song, Liked Songs, Search
  {
    ComPtr<IObjectCollection> tasks_collection;
    hr = CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                          CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&tasks_collection));
    if (SUCCEEDED(hr)) {
      auto link_play = CreateShellLink(exe_path, L"Play / Pause", L"--action=toggle-play", L"Toggle playback state", 0);
      if (link_play) tasks_collection->AddObject(link_play.Get());

      auto link_next = CreateShellLink(exe_path, L"Next Song", L"--action=next-track", L"Skip to next track", 0);
      if (link_next) tasks_collection->AddObject(link_next.Get());

      auto link_fav = CreateShellLink(exe_path, L"Liked Songs", L"--action=liked-songs", L"Play favorite music", 0);
      if (link_fav) tasks_collection->AddObject(link_fav.Get());

      auto link_search = CreateShellLink(exe_path, L"Search", L"--action=search", L"Search library and online music", 0);
      if (link_search) tasks_collection->AddObject(link_search.Get());

      dest_list->AddUserTasks(tasks_collection.Get());
    }
  }

  hr = dest_list->CommitList();
  return SUCCEEDED(hr);
}

void JumpListManager::ClearJumpList() {
  ComPtr<ICustomDestinationList> dest_list;
  HRESULT hr = CoCreateInstance(CLSID_DestinationList, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dest_list));
  if (SUCCEEDED(hr)) {
    dest_list->SetAppID(kAppUserModelID);
    dest_list->DeleteList(nullptr);
  }
}
