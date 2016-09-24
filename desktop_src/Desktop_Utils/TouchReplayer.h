// TouchReplayer.h

#pragma once

#include <string>
#include <vector>

struct touchEvent {
    int pointerid;
    int action;
    float x;
    float y;
    double time;
};

typedef void ( * callback_function)(int, int, float, float);

class TouchReplayer
{
public:
    TouchReplayer();
    virtual ~TouchReplayer();

    void LoadTouchLogFromFile(const std::string& filename);
    void PlaybackRecentEvents(float timeInSeconds, callback_function cbfunc);

protected:
    std::vector<touchEvent> m_touchEvents;
    int m_playbackIdx;

private:
    TouchReplayer(const TouchReplayer&);              ///< disallow copy constructor
    TouchReplayer& operator = (const TouchReplayer&); ///< disallow assignment operator
};
