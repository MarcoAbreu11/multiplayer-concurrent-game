package state;

public class PlayerData {
    public final String id;
    public final float x;
    public final float y;
    public final float radius;
    public final float angle;
    public final float mass;
    public final boolean isMe;

    public PlayerData(String id, float x, float y, float radius, float angle, float mass, boolean isMe) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.radius = radius;
        this.angle = angle;
        this.mass = mass;
        this.isMe = isMe;
    }

    @Override
    public String toString() {
        return "PlayerData{id=" + id + ", x=" + x + ", y=" + y + ", r=" + radius + ", angle=" + angle + ", mass=" + mass + ", isMe=" + isMe + "}";
    }
}
