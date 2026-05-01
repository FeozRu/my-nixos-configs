{ config, pkgs, lib, ... }:

let
  yaziFilemanager1 = pkgs.writeTextFile {
    name = "yazi-filemanager1";
    executable = true;
    destination = "/bin/yazi-filemanager1";
    text = ''
      #!${pkgs.python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3
      import os, subprocess, sys, urllib.parse
      from gi.repository import Gio, GLib

      XML = """<node>
        <interface name="org.freedesktop.FileManager1">
          <method name="ShowFolders">
            <arg name="uris" type="as" direction="in"/>
            <arg name="startupId" type="s" direction="in"/>
          </method>
          <method name="ShowItems">
            <arg name="uris" type="as" direction="in"/>
            <arg name="startupId" type="s" direction="in"/>
          </method>
          <method name="ShowItemProperties">
            <arg name="uris" type="as" direction="in"/>
            <arg name="startupId" type="s" direction="in"/>
          </method>
        </interface>
      </node>"""

      def uri_to_path(uri):
          if uri.startswith("file://"):
              return urllib.parse.unquote(uri[7:])
          return uri

      def open_in_yazi(path):
          subprocess.Popen(
              ["kitty", "-e", "yazi", path],
              start_new_session=True,
              stdout=subprocess.DEVNULL,
              stderr=subprocess.DEVNULL,
          )

      def handle_method_call(conn, sender, obj, iface, method, params, invocation):
          args = params.unpack()
          uris = args[0] if args else []
          if uris:
              open_in_yazi(uri_to_path(uris[0]))
          invocation.return_value(None)

      def on_bus_acquired(conn, name):
          info = Gio.DBusNodeInfo.new_for_xml(XML)
          conn.register_object(
              "/org/freedesktop/FileManager1",
              info.interfaces[0],
              handle_method_call, None, None,
          )

      loop = GLib.MainLoop()
      Gio.bus_own_name(
          Gio.BusType.SESSION,
          "org.freedesktop.FileManager1",
          Gio.BusNameOwnerFlags.REPLACE,
          on_bus_acquired, None,
          lambda *a: loop.quit(),
      )
      loop.run()
    '';
  };
in
{
  home.packages = [ yaziFilemanager1 ];

  systemd.user.services.yazi-filemanager1 = {
    Unit = {
      Description = "FileManager1 D-Bus service (opens Yazi instead of Dolphin)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.lib.getExe' yaziFilemanager1 "yazi-filemanager1"}";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
