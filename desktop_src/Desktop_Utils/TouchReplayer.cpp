// TouchReplayer.cpp

#include "TouchReplayer.h"
#include "StringFunctions.h"
#include "Logging.h"

#include <fstream>
#include <stdlib.h>

TouchReplayer::TouchReplayer()
: m_touchEvents()
, m_playbackIdx(0)
{
}

TouchReplayer::~TouchReplayer()
{
}

void TouchReplayer::LoadTouchLogFromFile(const std::string& filename)
{
    m_touchEvents.clear();
    m_playbackIdx = 0;

    std::ifstream ifs;
    ifs.open(filename.c_str(), std::ifstream::in);

    if (!ifs.is_open())
    {
        LOG_ERROR("Layout file [%s] not found.", filename.c_str());
        return;
    }

    // Read each line in the ASCII file
    std::string line;
    while (!std::getline(ifs, line).eof())
    {
        if (line.empty()) // Blank lines ignored
            continue;

        //LOG_INFO("line-> %s", line.c_str());
        const std::vector<std::string> tokat = split(line, '@');
        if (tokat.size() < 2)
            continue;
        const std::vector<std::string> tokcol = split(tokat[1], ':');
        if (tokcol.size() < 2)
            continue;
        const std::string timestr = tokcol[0];
        const std::vector<std::string> tokcom = split(tokcol[1], ',');
        if (tokcom.size() < 4)
            continue;

        touchEvent ev;
        ev.time = atof(tokcol[0].c_str());
        ev.pointerid = atoi(tokcom[0].c_str());
        ev.action = atoi(tokcom[1].c_str());
        ev.x = atof(tokcom[2].c_str());
        ev.y = atof(tokcom[3].c_str());

        m_touchEvents.push_back(ev);
    }

    if (m_touchEvents.empty())
        return;

    // Adjust times for convenient playback
    const float firstTime = m_touchEvents[0].time;
    const float toff = -firstTime + 1.f;
    for (std::vector<touchEvent>::iterator it = m_touchEvents.begin();
        it != m_touchEvents.end();
        ++it)
    {
        touchEvent& pte = *it;
        pte.time += toff;
    }

    ifs.close();
}

void TouchReplayer::PlaybackRecentEvents(float timeInSeconds, callback_function cbfunc)
{
    if (m_touchEvents.empty())
        return;

    if (cbfunc == NULL)
        return;

    if (m_playbackIdx >= static_cast<int>(m_touchEvents.size()))
        return;

    const touchEvent* iev = &m_touchEvents[m_playbackIdx];
    while (iev->time < timeInSeconds)
    {
        cbfunc(iev->pointerid, iev->action, iev->x, iev->y);
        ++m_playbackIdx;
        if (m_playbackIdx >= static_cast<int>(m_touchEvents.size()))
            return;

        iev = &m_touchEvents[m_playbackIdx];
    }
}
