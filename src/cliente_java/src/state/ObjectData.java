package state;

public class ObjectData {
    public enum Type { FOOD, POISON }

    public final String id;
    public final float x;
    public final float y;
    public final float radius;
    public final Type type;

    public ObjectData(String id, float x, float y, float radius, Type type) {
        this.id = id;
        this.x = x;
        this.y = y;
        this.radius = radius;
        this.type = type;
    }

    @Override
    public String toString() {
        return "ObjectData{id=" + id + ", x=" + x + ", y=" + y + ", r=" + radius + ", type=" + type + "}";
    }
}
