using System.Web;
using System.Web.Optimization;

namespace VentasWeb
{
    public class BundleConfig
    {
        public static void RegisterBundles(BundleCollection bundles)
        {
            // ── IMPORTANTE: deshabilita el caché de bundles en desarrollo ──
            // Sin esto, los cambios en JS/CSS no se reflejan hasta limpiar caché
            BundleTable.EnableOptimizations = false;

            bundles.Add(new ScriptBundle("~/bundles/jquery").Include(
                        "~/Scripts/jquery-{version}.js"));

            bundles.Add(new ScriptBundle("~/bundles/jqueryval").Include(
                        "~/Scripts/jquery.validate*"));

            bundles.Add(new ScriptBundle("~/bundles/modernizr").Include(
                        "~/Scripts/modernizr-*"));

            bundles.Add(new ScriptBundle("~/bundles/bootstrap").Include(
                      "~/Scripts/bootstrap.js"));

            bundles.Add(new StyleBundle("~/Content/css").Include(
                      "~/Content/bootstrap.css",
                      "~/Content/site.css"));

            bundles.Add(new StyleBundle("~/Content/PluginsCSS").Include(
                      "~/Content/Plugins/datatables/css/jquery.dataTables.min.css",
                      "~/Content/Plugins/datatables/css/responsive.dataTables.min.css",
                      "~/Content/Plugins/fontawesome-free-5.15.2/css/all.min.css",
                      "~/Content/Plugins/sweetalert2/css/sweetalert.css",
                      "~/Content/Plugins/jquery-ui-1.12.1/jquery-ui.min.css",
                      "~/Content/Plugins/jquery-ui-1.12.1/jquery-ui-timepicker-addon.css",
                      "~/Content/Plugins/Bootstrap-Duallistbox/css/bootstrap-duallistbox.min.css"
                      ));

            bundles.Add(new ScriptBundle("~/Content/PluginsJS").Include(
                     "~/Content/Plugins/datatables/js/jquery.dataTables.min.js",
                     "~/Content/Plugins/datatables/js/dataTables.responsive.min.js",
                     "~/Content/Plugins/fontawesome-free-5.15.2/js/all.min.js",
                     "~/Content/Plugins/sweetalert2/js/sweetalert.js",
                     "~/Content/Plugins/jquery-ui-1.12.1/jquery-ui.min.js",
                     "~/Content/Plugins/jquery-ui-1.12.1/jquery-ui-timepicker-addon.js",
                     "~/Content/Plugins/jquery-ui-1.12.1/jquery-ui.es.js",
                     "~/Content/Plugins/Bootstrap-Duallistbox/js/jquery.bootstrap-duallistbox.min.js",
                     "~/Content/Plugins/jquery-loading-overlay/loadingoverlay.min.js",
                     "~/Scripts/jquery.validate.min.js"
                     ));
        }
    }
}