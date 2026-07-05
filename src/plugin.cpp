#include "SimpleIni.h";

std::vector<BSFixedString> menuNames;
int delay = 0;

static void Inject(BSFixedString menuName) {
    auto ui = UI::GetSingleton();
    if (!ui) return;

    GPtr<IMenu> menu = ui->GetMenu(menuName);
    if (!menu || !menu->uiMovie) {
        return;
    }

    auto movie = menu->uiMovie;
    GFxValue _root;
    movie->GetVariable(&_root, "_root");

    // not used atm, as it's require updating swf
    // GFxValue data;
    // movie->CreateObject(&data);
    // data.SetMember("delay", delay);
    // data.SetMember("menuName", GFxValue(menuName)); // maybe useful?
    // _root.SetMember("_lorebox", data);

    std::string containerName = "LoreBox_" + std::to_string(delay);
    GFxValue args[2];
    args[0] = GFxValue(containerName);
    args[1] = GFxValue(5769);
    _root.Invoke("createEmptyMovieClip", nullptr, args, 2);
    if (movie->GetVariable(&_root, ("_root." + containerName).c_str())) {
        GFxValue args[1];
        args[0] = GFxValue("lorebox_inject.swf");
        _root.Invoke("loadMovie", nullptr, args, 1);
    }
}

class eventSink : public BSTEventSink<MenuOpenCloseEvent> {
    BSEventNotifyControl ProcessEvent(const MenuOpenCloseEvent* event, BSTEventSource<MenuOpenCloseEvent>*) {
        if (event->opening && std::ranges::find(menuNames, event->menuName) != menuNames.end()) {
            Inject(event->menuName);
        }
        return BSEventNotifyControl::kContinue;
    }
};

void LoadConfig() {
    CSimpleIniA ini;
    ini.SetMultiKey(true);
    std::string filePath = "Data/SKSE/Plugins/LoreBox.ini";
    if (ini.LoadFile(filePath.c_str()) == SI_OK) {
        delay = std::stoi(ini.GetValue("Main", "iDelay", "0"));
        CSimpleIniA::TNamesDepend allMenus;
        ini.GetAllValues("Menus", "sMenu", allMenus);
        menuNames.reserve(allMenus.size());
        for (const auto &menu : allMenus) {
            menuNames.push_back(menu.pItem);
        }
    }
}

void Setup() {
    LoadConfig();
    static eventSink g_sink;
    UI::GetSingleton()->AddEventSink(&g_sink);
}

SKSEPluginLoad(const SKSE::LoadInterface *skse) {
    SKSE::Init(skse);

    SKSE::GetMessagingInterface()->RegisterListener([](SKSE::MessagingInterface::Message *message) {
        if (message->type == SKSE::MessagingInterface::kDataLoaded) {
            Setup();
        }
    });

    return true;
}