class AdhesionesController < ApplicationController
	before_action :authenticate_user!, except: [:descargar]
  before_action :set_tarea_pendiente
  before_action :set_flujo
	before_action :set_datos
  before_action :set_crea_archivo, only: [:descargar]

	def actualizar #DZC ACCESO A APL-025 PPF-016
	end

	def actualizar_guardar #DZC TAREA APL-025 PPF-016 TERMINO
    @adhesion.assign_attributes(adhesion_params)
		# @adhesion.manifestacion_de_interes_id = @manifestacion_de_interes.id
    @adhesion.flujo_id = @flujo.id
    @adhesion.is_ppf = @ppp.present?
    respond_to do |format|
      
      if @adhesion.save
        @rechazadas = []
        continua_flujo_segun_tipo_tarea
        if @tarea.codigo == Tarea::COD_PPF_016 || @tarea.codigo == Tarea::COD_PPF_017
          format.js { flash[:success] = "Adhesión solicitada correctamente"
            render js: "window.location='#{root_url}'" 
          }
        elsif @tarea.codigo == Tarea::COD_APL_025
          format.js { 
            flash[:success] = "Adhesión solicitada correctamente"
            render js: "window.location='#{actualizar_adhesion_path(@tarea_pendiente)}'" 
          }
        else
          format.js { flash[:success] = "Adhesión solicitada correctamente" }
        end
      else
      	# ap @adhesion.errors.messages
        format.js { flash.now[:error] = @adhesion.errors.messages}
      end
    end
	end

  def revisar #DZC APL-028
  end

  # def revisar_guardar #DZC APL-028 PPF-017
  #   # @al_menos_se_acepto_uno = false
  #   seleccionados = params[:adhesion][:elementos_seleccionados]
  #   estado = params[:adhesion][:estado_elementos]
  #   justificacion = params[:adhesion][:justificacion_elementos]
  #   @adhesion.estado_elementos = estado
  #   @adhesion.justificacion_elementos = justificacion
  #   @adhesion.validar_clasificar = true

  #   respond_to do |format|
  #     if @adhesion.valid?
  #       data = @pendientes

  #       seleccionados.each do |seleccionado|
          
  #         datos = data[seleccionado.to_i]
  #         if estado == "true"
  #           # @al_menos_se_acepto_uno = true
  #           #Ademas se pobla la tabla dato_productivo_elemento_adheridos
  #           data[seleccionado.to_i][:revisado] = true
  #           data[seleccionado.to_i][:observaciones] = justificacion
  #           @adhesion.poblar_data(datos, @flujo)
  #         elsif estado == "false"
  #           data[seleccionado.to_i][:revisado] = false
  #           data[seleccionado.to_i][:observaciones] = justificacion
  #         else
  #           data[seleccionado.to_i][:revisado] = false
  #           data[seleccionado.to_i][:observaciones] = nil
  #         end
          
  #       end
  #       @adhesion.adhesiones_data = data
  #       # @adhesion.manifestacion_de_interes_id = @manifestacion_de_interes.id
  #       @adhesion.flujo_id = @flujo.id
  #       @adhesion.tipo = "revision"
  #       @adhesion.save
  #       set_datos
        
  #       continua_flujo_segun_tipo_tarea 
  #       format.js { flash[:success] = "Adhesiones revisadas correctamente" }
  #     else
  #       format.js { }
  #     end
  #   end
  # end

  def revisar_guardar #DZC APL-028 PPF-017
    
    correcto = false
    ActiveRecord::Base.transaction do
      # @al_menos_se_acepto_uno = false
      aceptados = params[:aceptado]
      observaciones = params[:observacion]
      data = @por_revisar_todas
      adh = nil
      procesar_tareas_25 = []

      aceptados.each do |k,v|

        key = k.split("|")
        adhesion_id = key.first
        posicion = key.last
        nueva_adhesion = false
        
        if adh.nil? || adh.id.to_s != adhesion_id.to_s
          adh = Adhesion.unscoped.find(adhesion_id) 
          nueva_adhesion = true
        end
        idx = 0
        datos = nil
        data[adh.id].each_with_index do |fila, _idx|
          if fila[:posicion].to_s == posicion.to_s
            datos = fila
            idx = _idx
          end
        end
        if v == "true"
          # @al_menos_se_acepto_uno = true
          #Ademas se pobla la tabla dato_productivo_elemento_adheridos
          
          data[adh.id][idx][:revisado] = true
          data[adh.id][idx][:observaciones] = observaciones[k]
          @adhesion.poblar_data(datos, @flujo, adh.archivos_adhesion_y_documentacion, adh)

          procesar_tareas_25 << adh if adh.externa && nueva_adhesion
        elsif v == "false"
          data[adh.id][idx][:revisado] = false
          data[adh.id][idx][:observaciones] = observaciones[k]
          #si observo debo crear igual datos de usuario para tareas 25.1 y 25.2
          procesar_tareas_25 << adh if adh.externa && nueva_adhesion
        else
          data[adh.id][idx][:revisado] = false
          data[adh.id][idx][:observaciones] = nil
        end
        
      end

      procesar_tareas_25.each do |adh|
        adh.crear_data_nuevas_tareas_25
      end
      @adhesiones.each do |adh|
        if !data[adh.id].blank?
          adh.adhesiones_data = data[adh.id]
          # @adhesion.manifestacion_de_interes_id = @manifestacion_de_interes.id
          adh.flujo_id = @flujo.id
          adh.tipo = "revision"
          correcto = true if adh.save
        end
      end
    end
    respond_to do |format|
      if correcto
        set_datos
        
        continua_flujo_segun_tipo_tarea 
        format.js { flash[:success] = "Adhesiones revisadas correctamente" }
      else
        format.js { flash.now[:error] = "Error al revisar adhesiones, reintente"}
      end
    end
  end

  def retirar_elemento

    ae = AdhesionElemento.find(params[:adhesion][:elemento_retirado_id])
    @adhesion = ae.adhesion
    @adhesion.elemento_retirado_id = params[:adhesion][:elemento_retirado_id]

    aer = AdhesionElementoRetirado.new

    fila = ae.fila
    fila[:fecha_retiro] = Date.today

    aer.adhesion_id = ae.adhesion_id
    aer.persona_id = ae.persona_id
    aer.alcance_id = ae.alcance_id
    aer.establecimiento_contribuyente_id = ae.establecimiento_contribuyente_id
    aer.maquinaria_id = ae.maquinaria_id
    aer.otro_id = ae.otro_id
    aer.fila = fila
    #copiar archivos
    aer.archivo_adhesion = File.open(ae.archivo_adhesion.file.file) if ae.archivo_adhesion.present?
    aer.archivo_respaldo = File.open(ae.archivo_respaldo.file.file) if ae.archivo_respaldo.present?
    aer.archivo_retiro = params[:adhesion][:documento_justificacion]

    respond_to do |format|

      if aer.valid?
        aer.save
        AuditoriaElemento.where(adhesion_elemento_id: ae.id).update_all(adhesion_elemento_id: nil)
        ae.destroy
        set_datos

        format.js { 
          flash[:success] = "Elemento retirado correctamente"
        }
      else
        #pasamos error de archivo a adhesion
        @adhesion.errors.add(:documento_justificacion, aer.errors[:archivo_retiro].first)
        format.js {}
      end
    end
  end

  def descargar
    #enviamos el archivo para ser descargado
    send_data @archivo.to_stream.read, type: 'application/xslx', charset: "iso-8859-1", filename: "formato_adhesion.xlsx"
  end

  def descargar_compilado
    require 'zip'
    archivo_zip = Zip::OutputStream.write_buffer do |stream|
      @adhesiones.each do |adhesion|
        adhesion.archivos_adhesion_y_documentacion.each do |archivo|
          if File.exists?(archivo.path)
            nombre = archivo.file.identifier
            # rename the file
            stream.put_next_entry(nombre)
            # add file to zip
            stream.write IO.read((archivo.current_path rescue archivo.path))
          end
        end
      end
    end
    archivo_zip.rewind
    #enviamos el archivo para ser descargado
    send_data archivo_zip.sysread, type: 'application/zip', charset: "iso-8859-1", filename: "documentacion.zip"
  end

  #DZC agrega al campo data de la tarea_pendiente 
  def continua_flujo_segun_tipo_tarea(condicion_de_salida=nil)
    case @tarea.codigo
    when Tarea::COD_APL_025
      @tarea_pendiente.pasar_a_siguiente_tarea ['A'], {}, false
    when Tarea::COD_APL_028
      # DZC 2018-11-06 11:04:40 se modifica acorde a los cambios realizados en las condiciones de continuación de flujo
      # DZC 2018-11-08 14:58:14 se corrige erro en acceso a condición 'C'
       
      if @todas.present? && @todas[:aceptada].present? && (@tarea_pendiente.data.blank? || @tarea_pendiente.data!={primera_ejecucion: true})
        #@tarea_pendiente.update(data: {primera_ejecucion: false})#no se para que se usa, no encontree el sentido
        @tarea_pendiente.pasar_a_siguiente_tarea 'C', {}, false
      end
      @tarea_pendiente.pasar_a_siguiente_tarea 'A', {}, false

      # auditorias=Auditoria.where(manifestacion_de_interes_id: @manifestacion_de_interes.id).pluck(:final)
      # @tarea_pendiente.pasar_a_siguiente_tarea 'C', {}, false
      # if (!auditorias.include?(nil) && !auditorias.include?(false))
      #   @tarea_pendiente.pasar_a_siguiente_tarea 'A'
      # end
    when Tarea::COD_PPF_016, Tarea::COD_PPF_017
      if @tarea_pendiente.data == {primera_ejecucion: true}
        @tarea_pendiente.update(data: {primera_ejecucion: false})
        @tarea_pendiente.pasar_a_siguiente_tarea 'A', {primera_ejecucion: true}, false
      end
    end    
  end

	private
	
    #asigna valor de id de tarea pendiente, leyendolo desde la URL (esto es neceario por que no se traspasa desde la jerarquia superior)
    def set_tarea_pendiente
      @tarea_pendiente = TareaPendiente.find(params[:tarea_pendiente_id])
      autorizado? @tarea_pendiente if params[:action] != "descargar"
      @tarea = @tarea_pendiente.tarea #crea una instancia de tarea a través de la forean key de tarea_pendiente (primary de tarea)
      @tarea = Tarea.find(params[:tarea_id]) if !params[:tarea_id].blank?
    end

    #DZC define el flujo y tipo_instrumento, junto con la manifestación o el proyecto según corresponda, para efecto de completar datos. El id de la manifestación se obtiene del flujo correspondiente a la tarea pendiente.
    def set_flujo
      @flujo = @tarea_pendiente.flujo
      @tipo_instrumento=@flujo.tipo_instrumento
      @manifestacion_de_interes = @flujo.manifestacion_de_interes_id.blank? ? nil : ManifestacionDeInteres.find(@flujo.manifestacion_de_interes_id)
      @manifestacion_de_interes.update(tarea_codigo: @tarea.codigo) unless @manifestacion_de_interes.blank?
      @proyecto = @flujo.proyecto_id.blank? ? nil : Proyecto.find(@flujo.proyecto_id)
      @ppp = @flujo.programa_proyecto_propuesta_id.blank? ? nil : ProgramaProyectoPropuesta.find(@flujo.programa_proyecto_propuesta_id)
    end

		def set_datos
			# @manifestacion_de_interes = ManifestacionDeInteres.find(params[:id])
			@descargables = @tarea_pendiente.get_descargables
      # @adhesion = Adhesion.find_by(manifestacion_de_interes_id: @manifestacion_de_interes.id)
      
      @adhesion = Adhesion.find_by(flujo_id: @flujo.id)
			@adhesion = Adhesion.new(flujo_id: @flujo.id) if @adhesion.nil?
      @rechazadas = @adhesion.adhesiones_rechazadas
      @pendientes = @adhesion.adhesiones_pendientes
      @no_pendientes = @adhesion.adhesiones_aceptadas_y_observadas
      @retiradas = @adhesion.adhesiones_retiradas
      @todas = @adhesion.adhesiones_todas

      @adhesiones = Adhesion.unscoped.where(flujo_id: @flujo.id)
      @todas_mias = @adhesion.adhesiones_todas_mias
      @rechazadas_todas = {}
      @pendientes_todas = {}
      @no_pendientes_todas = {}
      @retiradas_todas = {}
      @todas_todas = {}
      @por_revisar_todas = {}
      @adhesiones.each do |adh|
        @rechazadas_todas[adh.id] = adh.adhesiones_rechazadas
        @pendientes_todas[adh.id] = adh.adhesiones_pendientes
        @no_pendientes_todas[adh.id] = adh.adhesiones_aceptadas_y_observadas
        @retiradas_todas[adh.id] = adh.adhesiones_retiradas
        @todas_todas[adh.id] = adh.adhesiones_todas
        @por_revisar_todas[adh.id] = adh.adhesiones_por_revisar
      end
		end

		def adhesion_params
      params.require(:adhesion).permit(
        :archivo_elementos,
        :archivo_elementos_cache,
        :archivos_adhesion_y_documentacion_cache,
        archivos_adhesion_y_documentacion: []
      )
		end

    def set_crea_archivo
      titulos = Adhesion.columnas_excel
      datos = []
      if [Tarea::ID_APL_025_1].include?(@tarea.id)
        data_primera_fila = [
          "",
          params[:ri],#rut institucionm
          params[:ni],#nombre institucion
          "",
          params[:ti],#tipo institucion
          "",
          params[:md],#matriz direccion
          params[:mc],#matriz comuna,
          params[:rr],#rut representante
          params[:nr],#nombre representante
          "",
          params[:fr],#fono representante
          params[:er],#email representante
          "",
          "",
          "",
          "",
          "",
          "",
          "",
          "",
          ""
        ]
        datos = [data_primera_fila]
      else
        datos = @adhesion.desparseas_adhesiones_rechazadas unless @adhesion.new_record?
      end
      dominios = Adhesion.dominios(@ppp.present?)
      @archivo = ExportaExcel.formato(nil, titulos, dominios, datos, "Adhesiones" )
    end

end