#include <Application.h>
#include <AppFileInfo.h>
#include <Bitmap.h>
#include <File.h>
#include <IconUtils.h>
#include <TranslationUtils.h>
#include <memory>

int main(int argc, char** argv)
{
    if (argc != 4)
        return 2;
    BApplication application("application/x-vnd.wordcraft-package-icon");
    BFile file(argv[1], B_READ_WRITE);
    BAppFileInfo info(&file);
    if (info.InitCheck() != B_OK)
        return 1;
    for (int i = 0; i < 2; i++) {
        std::unique_ptr<BBitmap> source(BTranslationUtils::GetBitmapFile(argv[i + 2]));
        if (!source || source->InitCheck() != B_OK)
            return 1;
        BBitmap icon(source->Bounds(), B_CMAP8);
        if (icon.InitCheck() != B_OK
            || BIconUtils::ConvertToCMAP8(source.get(), &icon) != B_OK
            || info.SetIcon(&icon, i == 0 ? B_LARGE_ICON : B_MINI_ICON) != B_OK)
            return 1;
    }
    return 0;
}
