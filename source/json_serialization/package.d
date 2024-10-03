module json_serialization;

import std.stdio;
import std.traits;
import std.typecons;
import std.datetime;
import std.json;
import std.algorithm : startsWith;

// TODO: Handle Array and Dict
T deserializeJSONValue(T)(JSONValue data)
{
    static if (is(T == struct))
        T result;
    else
        T result = new T;

    alias fieldTypes = FieldTypeTuple!(T);
    alias fieldNames = FieldNameTuple!(T);

    static foreach(idx, fieldName; fieldNames)
    {
        {
            // Field name same as memberName unless @JSONFieldName
            // attribute added to the member.
            enum name = getJSONFieldName!(T, fieldName);

            // Add to Struct if exists in the input JSONValue
            mixin("if (\"" ~ name ~ "\" in data) result." ~ fieldName ~ " = data[\"" ~ name ~ "\"].get!" ~ fieldTypes[idx].stringof ~ ";");
        }
    }

    return result;
}

/// UDA.
struct JSONFieldName
{
    string name;
}

/// UDA. struct members with @JSONFieldIgnore will be ignored while parsing JSON 
public enum JSONFieldIgnore; 

// TODO: Add new UDA for emitNull

string getJSONFieldName(T, string member)()
{
    static if (getUDAs!(__traits(getMember, T, member), JSONFieldName).length > 0)
        return getUDAs!(__traits(getMember, T, member), JSONFieldName)[0].name;

    return member;
}

bool isJSONFieldIgnored(T, string member)()
{
    return hasUDA!(__traits(getMember, T, member), JSONFieldIgnore);
}

string nullableType(T)()
{
    alias types = AliasSeq!(
        bool,
        short,
        ushort,
        int,
        uint,
        long,
        ulong,
        char,
        float,
        double,
        real,
        string
    );

    foreach(t; types)
    {
        if (is(T == Nullable!t))
            return t.stringof;
    }
    return "string";
}

JSONValue serializeToJSONValue(T)(T data)
{
    static if (isArray!(T))
    {
        JSONValue output = JSONValue.emptyArray;
        foreach(d; data)
            output.array ~= d.serializeToJSONValue;

        return output;
    }
    else
    {
        JSONValue result;

        alias fieldTypes = FieldTypeTuple!(T);
        alias fieldNames = FieldNameTuple!(T);
        alias fieldValues = data.tupleof;   

        static foreach(idx, fieldName; fieldNames)
        {
            {
                // TODO: Check if the field is struct/class
                static if (!isJSONFieldIgnored!(T, fieldName))
                {
                    // Field name same as memberName unless @JSONFieldName
                    // attribute added to the member.
                    enum name = getJSONFieldName!(T, fieldName);

                    static if (fieldTypes[idx].stringof.startsWith("Nullable!"))
                    {
                        if (!fieldValues[idx].isNull)
                            result[name] = JSONValue(fieldValues[idx].get);
                    }
                    else
                        result[name] = JSONValue(fieldValues[idx]);
                }
            }
        }

        return result;
    }
}

string serializeToJSONValueString(T)(T data)
{
    return data.serializeToJSONValue.toString;
}

T deserializeJSONValueString(T)(string data)
{
     return deserializeJSONValue!T(parseJSON(data));
}

unittest
{
    struct KeyValue1
    {
        string key;
        int value;
    }

    auto data1 = KeyValue1("ABCD", 100);
    JSONValue expect1;
    expect1["key"] = "ABCD";
    expect1["value"] = 100;
    assert(data1.serializeToJSONValue == expect1);

    struct KeyValue2
    {
        @JSONFieldName("name") string key;
        @JSONFieldIgnore string key1;
        int value;
    }

    auto data2 = KeyValue2("ABCD", "EFGH", 200);
    JSONValue expect2;
    expect2["name"] = "ABCD";
    expect2["value"] = 200;
    assert(data2.serializeToJSONValue == expect2);

    // Deserialization
    assert(deserializeJSONValue!KeyValue1(expect1) == data1);

    struct KeyValue3
    {
        string key;
        Nullable!int value1;
        Nullable!int value2;
    }

    auto data3 = KeyValue3("ABCD", 200.nullable);
    JSONValue expect3;
    expect3["key"] = "ABCD";
    expect3["value1"] = 200;
    assert(data3.serializeToJSONValue == expect3);

    // Array of Struct
    auto data4 = [KeyValue1("ABCD", 100), KeyValue1("EFGH", 200)];
    JSONValue expect4 = JSONValue.emptyArray;
    JSONValue a;
    a["key"] = "ABCD";
    a["value"] = 100;
    expect4.array ~= a;

    JSONValue b;
    b["key"] = "EFGH";
    b["value"] = 200;
    expect4.array ~= b;

    assert(data4.serializeToJSONValue == expect4);
}
