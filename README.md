# Estado operativo del forecasting de remision de leche

Esta rama la actualiza el workflow mensual. El codigo y la documentacion se mantienen en main.

- estado/: SQLite y archivos necesarios para continuar el historial.
- publico/: reportes HTML/CSV que publica GitHub Pages; no contiene SQLite.
- manifiesto_md5.csv: control de integridad de los archivos de estado.
- ultima_comprobacion.csv: fecha, codigo utilizado y resultado del ultimo ciclo.

No modificar a mano, borrar ni reinicializar esta rama para resolver un error.
La base de esta rama contiene exclusivamente datos publicos y resultados del proyecto.
